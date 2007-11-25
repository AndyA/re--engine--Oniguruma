/* Oniguruma.xs */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <pcre.h>
#include <oniguruma.h>
#include "Oniguruma.h"

REGEXP *
Oniguruma_comp( pTHX_ const SV * const pattern, const U32 flags ) {
    REGEXP *rx;
    regex_t *onig;

    STRLEN plen;
    UChar *exp = ( UChar * ) SvPV( ( SV * ) pattern, plen );
    UChar *exp_end = exp + plen;
    U32 extflags = flags;

    OnigOptionType option = ONIG_OPTION_NONE;

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

    OnigEncoding enc = ONIG_ENCODING_ASCII;
    OnigSyntaxType *syntax = ONIG_SYNTAX_PERL;
    OnigErrorInfo err;
    int rc, nparens;

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

#if 0
    /* If named captures are defined make rx->paren_names */
    pcre_fullinfo( ri, NULL, PCRE_INFO_NAMECOUNT, &namecount );

    if ( namecount <= 0 ) {
        rx->paren_names = NULL;
    }
    else {
        Oniguruma_make_nametable( rx, ri, namecount );
    }

    /* set up space for the capture buffers */
    pcre_fullinfo( ri, NULL, PCRE_INFO_SIZE, &length );
    rx->intflags = ( U32 ) length;

    /* Check how many parens we need */
    pcre_fullinfo( ri, NULL, PCRE_INFO_CAPTURECOUNT, &nparens );

    rx->nparens = rx->lastparen = rx->lastcloseparen = nparens;
    Newxz( rx->offs, nparens + 1, regexp_paren_pair );
#endif

    /* return the regexp */
    return rx;

#if 0
    /* pcre_compile */
    int options = PCRE_DUPNAMES;

    /* named captures */
    int namecount;

    /* C<split " ">, bypass the PCRE engine alltogether and act as perl does */
    if ( flags & RXf_SPLIT && plen == 1 && exp[0] == ' ' )
        extflags |= ( RXf_SKIPWHITE | RXf_WHITE );

    /* RXf_START_ONLY - Have C<split /^/> split on newlines */
    if ( plen == 1 && exp[0] == '^' )
        extflags |= RXf_START_ONLY;

    /* RXf_WHITE - Have C<split /\s+/> split on whitespace */
    else if ( plen == 3 && strnEQ( "\\s+", exp, 3 ) )
        extflags |= RXf_WHITE;

    /* Perl modifiers to PCRE flags, /s is implicit and /p isn't used
     * but they pose no problem so ignore them */
    if ( flags & RXf_PMf_FOLD )
        options |= PCRE_CASELESS;       /* /i */
    if ( flags & RXf_PMf_EXTENDED )
        options |= PCRE_EXTENDED;       /* /x */
    if ( flags & RXf_PMf_MULTILINE )
        options |= PCRE_MULTILINE;      /* /m */

    /* The pattern is known to be UTF-8. Perl wouldn't turn this on unless it's
     * a valid UTF-8 sequence so tell PCRE not to check for that */
    if ( flags & RXf_UTF8 )
        options |= ( PCRE_UTF8 | PCRE_NO_UTF8_CHECK );
#endif
}

I32
Oniguruma_exec( pTHX_ REGEXP * const rx, char *stringarg, char *strend,
                char *strbeg, I32 minend, SV * sv, void *data, U32 flags ) {
    regex_t *onig = rx->pprivate;
    OnigOptionType option = ONIG_OPTION_NONE;
    OnigRegion *region = onig_region_new(  );
    int rc, i;

    rc = onig_search( onig, ( const UChar * ) stringarg,
                      ( const UChar * ) strend, ( const UChar * ) strbeg,
                      ( const UChar * ) strend, region, option );

    if ( rc == ONIG_MISMATCH ) {
        onig_region_free( region, 1 );
        return 0;
    }
    else if ( rc < 0 ) {
        /* TODO: Fix this static buffer */
        static UChar erbuf[ONIG_MAX_ERROR_MESSAGE_LEN];

        onig_region_free( region, 1 );
        onig_error_code_to_str( erbuf, rc );
        croak( "Oniguruma: %s", erbuf );
    }

    /* TODO: So how does /g work? */
    rx->subbeg = strbeg;
    rx->sublen = strend - strbeg;

    for ( i = 0; i < region->num_regs; i++ ) {
        rx->offs[i].start = region->beg[i];
        rx->offs[i].end = region->end[i];
    }
    for ( ; i <= rx->nparens; i++ ) {
        rx->offs[i].start = -1;
        rx->offs[i].end = -1;
    }

    onig_region_free( region, 1 );

    return 1;
}

char *
Oniguruma_intuit( pTHX_ REGEXP * const rx,
                  SV * sv, char *strpos,
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

/*
 * Internal utility functions
 */

// void
// Oniguruma_make_nametable( REGEXP * const rx,
//                           pcre * const ri, const int namecount ) {
//     unsigned char *name_table, *tabptr;
//     int name_entry_size;
//     int i;
//     IV j;
//     /* The name table */
//     pcre_fullinfo( ri, NULL, PCRE_INFO_NAMETABLE, &name_table );
//     /* Size of each entry */
//     pcre_fullinfo( ri, NULL, PCRE_INFO_NAMEENTRYSIZE, &name_entry_size );
//     rx->paren_names = newHV(  );
//     tabptr = name_table;
//     for ( i = 0; i < namecount; i++ ) {
//         const char *key = tabptr + 2;
//         int npar = ( tabptr[0] << 8 ) | tabptr[1];
//         SV *sv_dat = *hv_fetch( rx->paren_names, key, strlen( key ),
//                                 TRUE );
//         if ( !sv_dat )
//             croak( "panic: paren_name hash element allocation failed" );
//         if ( !SvPOK( sv_dat ) ) {
//             /* The first (and maybe only) entry with this name */
//             ( void ) SvUPGRADE( sv_dat, SVt_PVNV );
//             sv_setpvn( sv_dat, ( char * ) &( npar ), sizeof( I32 ) );
//             SvIOK_on( sv_dat );
//             SvIVX( sv_dat ) = 1;
//         }
//         else {
//             /* An entry under this name has appeared before, append */
// 
//             IV count = SvIV( sv_dat );
//             I32 *pv = ( I32 * ) SvPVX( sv_dat );
//             IV j;
//             for ( j = 0; j < count; j++ ) {
//                 if ( pv[i] == npar ) {
//                     count = 0;
//                     break;
//                 }
//             }
// 
//             if ( count ) {
//                 pv = ( I32 * ) SvGROW( sv_dat,
//                                        SvCUR( sv_dat ) +
//                                        sizeof( I32 ) + 1 );
//                 SvCUR_set( sv_dat, SvCUR( sv_dat ) + sizeof( I32 ) );
//                 pv[count] = npar;
//                 SvIVX( sv_dat )++;
//             }
//         }
// 
//         tabptr += name_entry_size;
//     }
// }

/* *INDENT-OFF* */

MODULE = re::engine::Oniguruma  PACKAGE = re::engine::Oniguruma
PROTOTYPES:ENABLE

void
ENGINE( ... )
PROTOTYPE:
PPCODE:
    XPUSHs( sv_2mortal( newSViv( PTR2IV( &onig_engine ) ) ) );
