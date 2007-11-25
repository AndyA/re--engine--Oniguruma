/* Oniguruma.xs */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <pcre.h>
#include <oniguruma.h>
#include "Oniguruma.h"

static int
_build_callback( const UChar * name, const UChar * name_end, int ngroups,
                 int *groups, regex_t * onig, void *handle ) {
    REGEXP *const rx = handle;
    SV *sv_dat = *hv_fetch( rx->paren_names, name, name_end - name, TRUE );

    // if ( 1 ) {
    //     char nbuf[256];
    //     char gbuf[256];
    //     char *gp = gbuf;
    //     int i, len = name_end - name;
    // 
    //     memcpy( nbuf, name, len );
    //     nbuf[len] = '\0';
    // 
    //     for ( i = 0; i < ngroups; i++ ) {
    //         if ( i ) {
    //             gp += sprintf( gp, ", " );
    //         }
    //         gp += sprintf( "%d", groups[i] );
    //     }
    // 
    //     fprintf( stderr, "# Name: %s, %d group(s): %s\n", nbuf, ngroups );
    // }

    if ( !sv_dat ) {
        croak( "Oniguruma: Failed to allocate paren_names hash" );
    }

    ( void ) SvUPGRADE( sv_dat, SVt_PVNV );

    /* TODO: Assumes sizeof(int) == sizeof(I32) */
    sv_setpvn( sv_dat, ( char * ) groups, sizeof( I32 ) * ngroups );
    SvIOK_on( sv_dat );
    SvIVX( sv_dat ) = ngroups;

    return 0;
}

static void
_build_name_map( REGEXP * const rx ) {
    regex_t *onig = rx->pprivate;
    if ( onig_number_of_names( onig ) ) {
        rx->paren_names = newHV(  );
        ( void ) onig_foreach_name( onig, _build_callback, rx );
    }
    else {
        rx->paren_names = NULL;
    }

}

REGEXP *
Oniguruma_comp( pTHX_ const SV * const pattern, const U32 flags ) {
    REGEXP *rx;
    regex_t *onig;
    STRLEN plen;
    UChar *exp = ( UChar * ) SvPV( ( SV * ) pattern, plen );
    UChar *exp_end = exp + plen;
    U32 extflags = flags;
    OnigOptionType option = ONIG_OPTION_NONE;
    OnigEncoding enc = ONIG_ENCODING_ASCII;
    OnigSyntaxType *syntax = ONIG_SYNTAX_PERL;
    OnigErrorInfo err;
    int rc, nparens;

    // ONIG_OPTION_NONE               no option
    // ONIG_OPTION_SINGLELINE         '^' -> '\A', '$' -> '\Z'
    // ONIG_OPTION_MULTILINE          '.' match with newline
    // ONIG_OPTION_IGNORECASE         ambiguity match on
    // ONIG_OPTION_EXTEND             extended exp form
    // ONIG_OPTION_FIND_LONGEST       find longest match
    // ONIG_OPTION_FIND_NOT_EMPTY     ignore empty match
    // ONIG_OPTION_NEGATE_SINGLELINE
    //       clear ONIG_OPTION_SINGLELINE which is enabled on
    //       ONIG_SYNTAX_POSIX_BASIC, ONIG_SYNTAX_POSIX_EXTENDED,
    //       ONIG_SYNTAX_PERL, ONIG_SYNTAX_PERL_NG, ONIG_SYNTAX_JAVA
    // 
    // ONIG_OPTION_DONT_CAPTURE_GROUP only named group captured.
    // ONIG_OPTION_CAPTURE_GROUP      named and no-named group captured.

    if ( flags & RXf_SPLIT ) {
        if ( plen == 0 ) {
            extflags |= RXf_NULL;
        }
        else if ( plen == 1 && exp[0] == ' ' ) {
            /* split " " */
            extflags |= ( RXf_SKIPWHITE | RXf_WHITE );
        }
    }

    if ( plen == 1 && exp[0] == '^' ) {
        /* split /^/ */
        extflags |= RXf_START_ONLY;
    }
    else if ( plen == 3 && strnEQ( "\\s+", ( const char * ) exp, 3 ) ) {
        /* split /\s+/ */
        extflags |= RXf_WHITE;
    }

    /* Perl modifiers to Oniguruma flags, /s is implicit and /p isn't used
     * but they pose no problem so ignore them */
    if ( flags & RXf_PMf_FOLD ) {
        option |= ONIG_OPTION_IGNORECASE;       /* /i */
    }

    if ( flags & RXf_PMf_EXTENDED ) {
        option |= ONIG_OPTION_EXTEND;   /* /x */
    }

    if ( flags & RXf_PMf_MULTILINE ) {
        option |= ONIG_OPTION_MULTILINE;        /* /m */
    }

    /* The pattern is known to be UTF-8. Perl wouldn't turn this on unless it's
     * a valid UTF-8 sequence so tell Oniguruma not to check for that */
    // if ( flags & RXf_UTF8 )
    //     option |= ( PCRE_UTF8 | PCRE_NO_UTF8_CHECK );

    if ( rc = onig_new( &onig, exp, exp_end,
                        option, enc, syntax, &err ), ONIG_NORMAL != rc ) {
        /* TODO: Fix this static buffer */
        static UChar erbuf[ONIG_MAX_ERROR_MESSAGE_LEN];
        onig_error_code_to_str( erbuf, rc, err );
        croak( "Oniguruma: %s", erbuf );
    }

    Newxz( rx, 1, REGEXP );
    rx->refcnt = 1;
    rx->extflags = extflags;
    rx->engine = &onig_engine;

    /* Preserve a copy of the original exp */
    rx->prelen = ( I32 ) plen;
    rx->precomp = SAVEPVN( ( char * ) exp, plen );

    /* qr// stringification, TODO: (?flags:exp) */
    rx->wraplen = rx->prelen;
    rx->wrapped = ( char * ) rx->precomp;

    /* Store our private object */
    rx->pprivate = onig;

    /* Allocate space for captures */
    nparens = onig_number_of_captures( onig );
    rx->nparens = rx->lastparen = rx->lastcloseparen = nparens;
    Newxz( rx->offs, nparens + 1, regexp_paren_pair );

    /* Build map: names => groups */
    _build_name_map( rx );

    /* return the regexp */
    return rx;
}

I32
Oniguruma_exec( pTHX_ REGEXP * const rx,
                char *stringarg, char *strend,
                char *strbeg, I32 minend, SV * sv, void *data, U32 flags ) {
    regex_t *onig = rx->pprivate;
    OnigOptionType option = ONIG_OPTION_NONE;
    OnigRegion *region = onig_region_new(  );
    int rc, i;
    // fprintf( stderr, "# %p %p %p\n", stringarg, strbeg, strend );
    rc = onig_search( onig, ( const UChar * ) strbeg,
                      ( const UChar * ) strend,
                      ( const UChar * ) stringarg,
                      ( const UChar * ) strend, region, option );
    if ( rc == ONIG_MISMATCH ) {
        onig_region_free( region, 1 );
        return 0;
    }
    else if ( rc < 0 ) {
        /* TODO: Fix this static buffer */
        static UChar erbuf[ONIG_MAX_ERROR_MESSAGE_LEN];
        onig_region_free( region, 1 );
        onig_error_code_to_str( erbuf, rc, NULL );
        croak( "Oniguruma: %s", erbuf );
    }

    rx->subbeg = strbeg;
    rx->sublen = strend - strbeg;
    for ( i = 0; i < region->num_regs; i++ ) {
        /* Copy matches */
        rx->offs[i].start = region->beg[i];
        rx->offs[i].end = region->end[i];
        // fprintf( stderr, "# %3d %p - %p\n", i, region->beg[i],
        //          region->end[i] );
    }

    for ( ; i <= rx->nparens; i++ ) {
        /* Blank remainder */
        rx->offs[i].start = -1;
        rx->offs[i].end = -1;
    }

    onig_region_free( region, 1 );
    return 1;
}

char *
Oniguruma_intuit( pTHX_ REGEXP *
                  const rx, SV * sv,
                  char *strpos,
                  char *strend, U32 flags, re_scream_pos_data * data ) {
    PERL_UNUSED_ARG( rx );
    PERL_UNUSED_ARG( sv );
    PERL_UNUSED_ARG( strpos );
    PERL_UNUSED_ARG( strend );
    PERL_UNUSED_ARG( flags );
    PERL_UNUSED_ARG( data );
    return NULL;
}

SV *
Oniguruma_checkstr( pTHX_ REGEXP * const rx ) {
    PERL_UNUSED_ARG( rx );
    return NULL;
}

void
Oniguruma_free( pTHX_ REGEXP * const rx ) {
    onig_free( rx->pprivate );
    // pcre_free( rx->pprivate );
}

void *
Oniguruma_dupe( pTHX_ REGEXP * const rx, CLONE_PARAMS * param ) {
    PERL_UNUSED_ARG( param );
    return rx->pprivate;
}

SV *
Oniguruma_package( pTHX_ REGEXP * const rx ) {
    PERL_UNUSED_ARG( rx );
    return newSVpvs( "re::engine::Oniguruma" );
}

/* *INDENT-OFF* */

MODULE = re::engine::Oniguruma  PACKAGE = re::engine::Oniguruma
PROTOTYPES:ENABLE

void
ENGINE( ... )
PROTOTYPE:
PPCODE:
    XPUSHs( sv_2mortal( newSViv( PTR2IV( &onig_engine ) ) ) );
