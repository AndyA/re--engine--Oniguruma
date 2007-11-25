/* Oniguruma.h */

#ifndef _ONIGURUMA_H_
#define _ONIGURUMA_H_

START_EXTERN_C EXTERN_C const regexp_engine onig_engine;
EXTERN_C REGEXP *Oniguruma_comp( pTHX_ const SV const *, const U32 );
EXTERN_C I32 Oniguruma_exec( pTHX_ REGEXP * const, char *, char *,
                             char *, I32, SV *, void *, U32 );
EXTERN_C char *Oniguruma_intuit( pTHX_ REGEXP * const, SV *, char *,
                                 char *, U32, re_scream_pos_data * );
EXTERN_C SV *Oniguruma_checkstr( pTHX_ REGEXP * const );
EXTERN_C void Oniguruma_free( pTHX_ REGEXP * const );

EXTERN_C SV *Oniguruma_package( pTHX_ REGEXP * const );

#ifdef USE_ITHREADS
EXTERN_C void *Oniguruma_dupe( pTHX_ REGEXP * const, CLONE_PARAMS * );
#endif

END_EXTERN_C const regexp_engine onig_engine = {
    Oniguruma_comp,
    Oniguruma_exec,
    Oniguruma_intuit,
    Oniguruma_checkstr,
    Oniguruma_free,
    Perl_reg_numbered_buff_fetch,
    Perl_reg_numbered_buff_store,
    Perl_reg_numbered_buff_length,
    Perl_reg_named_buff,
    Perl_reg_named_buff_iter,
    Oniguruma_package,
#if defined(USE_ITHREADS)
    Oniguruma_dupe,
#endif
};

#endif                          /* _ONIGURUMA_H_ */
