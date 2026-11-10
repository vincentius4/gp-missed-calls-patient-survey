/* paper0_tables.sas - every table of: Do missed calls to general practices reflect patients' reported ease of phone
   contact? A national observational study linking NHS England's cloud based telephony data to the GP Patient Survey.
   Haedong Kim, Sihyun Oh, Hajae Jeon, Jaeyong Shin. Licence: MIT (see LICENSE).

   Tables 1 to 3 and supplementary tables S1 to S9 (table S10 repeats table 2 with its slopes and two further waiting
   time measures, from the table 2 output), table S11 (the five definitions against appointment timing, waiting time
   thought about right and what patients did after failed contact) and table S12 (waiting times by time of day against
   reported ease). One run writes one text file per table to the folder OUT: one line per
   number, the labels (table, part, row, column) and the value separated by ' | ', formatted as printed in the paper.

   Inputs: the analysis datasets the authors built from the openly published files (folders SAS_OUT and SAS_OUT_min100
   under ROOT) and a few published files read directly (telephony durations, appointments, online consultation
   submissions, GP Patient Survey practice results, answered calls by time of day); the published files are those in the paper's reference list. The programs that build the analysis
   datasets are not part of this file. Software: SAS 9.4 for Windows (Base SAS, SAS/STAT; release TS1M7).

   How to run: set ROOT (and OUT if wanted) in PART 0 and run the whole file once (about 20 minutes). Each table starts
   as in a new SAS session (empty WORK, start-up options). Random steps (bootstrap, randomisation tests) use the seeds of
   the original analysis, so the intervals reproduce exactly. A table stops the run with an ERROR if an input is
   missing or a value cannot be selected uniquely. If folder names contain Korean characters, start SAS with the DBCS
   configuration (nls\1d\sasv9.cfg). ASCII only. */

* PART 0. Settings - the only lines to edit ;
* ROOT: the folder holding SAS_OUT, SAS_OUT_min100 and the published files (blank = environment variable PAPER0_ROOT) ;
%let ROOT = ;
* OUT: the folder for the output text files (blank = the folder output next to this program) ;
%let OUT = ;

%macro _part0;
    %global CODEDIR;
    %local p parent last;
    %let p = ;
    %if %symexist(_SASPROGRAMFILE) %then %let p = %sysfunc(dequote(%superq(_SASPROGRAMFILE)));
    %if %length(&p) < 4 and %sysfunc(envlen(SAS_EXECFILEPATH)) > 0 %then %let p = %qsysfunc(sysget(SAS_EXECFILEPATH));
    %if %length(&p) < 4 %then %let p = %qsysfunc(getoption(sysin));
    %if %length(&p) >= 4 %then %let CODEDIR = %qsubstr(&p, 1, %eval(%length(&p) - %length(%scan(&p, -1, \)) - 1));
    %if %length(&ROOT) = 0 and %sysfunc(envlen(PAPER0_ROOT)) > 0 %then %let ROOT = %qsysfunc(sysget(PAPER0_ROOT));
    %if %length(&ROOT) = 0 %then %do;
        %put ERROR: set ROOT in PART 0 or the environment variable PAPER0_ROOT.;
        %abort cancel;
    %end;
    %if %length(&OUT) = 0 %then %do;
        %if %length(&CODEDIR) = 0 %then %do;
            %put ERROR: the folder of this program was not found - set OUT in PART 0.;
            %abort cancel;
        %end;
        %let OUT = &CODEDIR.\output;
    %end;
    %if %sysfunc(fileexist(&OUT)) = 0 %then %do;
        %let last = %scan(&OUT, -1, \);
        %let parent = %qsubstr(&OUT, 1, %eval(%length(&OUT) - %length(&last) - 1));
        %let p = %sysfunc(dcreate(&last, &parent));
    %end;
    %if %sysfunc(fileexist(&OUT)) = 0 %then %do;
        %put ERROR: cannot create the output folder &OUT..;
        %abort cancel;
    %end;
%mend;
%_part0;

* PART 1. Input folders and libraries (found under ROOT by the files they contain) ;
/* 00_paths.sas - included by every program: finds the input folders under ROOT and defines the libraries.
   ASCII only. Prints nothing; writes one note to the log.
   ROOT is the folder in the environment variable PAPER0_ROOT if it is set, otherwise the parent of the folder
   holding the calling program. Folders under ROOT (three levels) are found by the files they contain, not by
   their names, so the downloaded files may be kept in folders of any name (README.md, How to run). */

options nofmterr;

/* ROOT is set in PART 0. */

/*---- 1. collect every folder at depth 1..3 under ROOT -------------------*/
data _dirs;
    length dir $900 nm $300 child $900 gchild $900;
    keep dir depth;

    dir = "&ROOT"; depth = 0; output;

    rc = filename('D0', "&ROOT");
    d0 = dopen('D0');
    if d0 = 0 then do;
        put "ERROR: cannot open ROOT"; rc = filename('D0'); abort cancel;
    end;
    do i = 1 to dnum(d0);
        nm    = dread(d0, i);
        child = catx('\', "&ROOT", nm);
        rc1 = filename('D1', child); d1 = dopen('D1');
        if d1 > 0 then do;
            dir = child; depth = 1; output;
            do j = 1 to dnum(d1);
                nm     = dread(d1, j);
                gchild = catx('\', child, nm);
                rc2 = filename('D2', gchild); d2 = dopen('D2');
                if d2 > 0 then do;
                    dir = gchild; depth = 2; output;
                    do k = 1 to dnum(d2);
                        nm  = dread(d2, k);
                        dir = catx('\', gchild, nm); depth = 3;
                        rc3 = filename('D3', dir); d3 = dopen('D3');
                        if d3 > 0 then do; output; rc3 = dclose(d3); end;
                        rc3 = filename('D3');
                    end;
                    rc2 = dclose(d2);
                end;
                rc2 = filename('D2');
            end;
            rc1 = dclose(d1);
        end;
        rc1 = filename('D1');
    end;
    rc = dclose(d0); rc = filename('D0');
run;

/*---- 2. for each folder, count files and flag what kinds it holds ------*/
data _scan _sample;
    length dir $900 fn $400 lastname $300 sample $400;
    set _dirs;
    keep dir lastname depth n_files f_cbtcsv f_cbtzip f_reg f_lsoa f_wf f_nspl f_ons f_oc f_gpps f_cbta;

    lastname = scan(dir, -1, '\');
    n_files  = 0;
    f_cbtcsv = 0; f_cbtzip = 0; f_reg = 0; f_lsoa = 0;
    f_wf     = 0; f_nspl   = 0; f_ons = 0; f_oc   = 0; f_gpps = 0; f_cbta = 0;

    rc = filename('SC', dir);
    ds = dopen('SC');
    if ds > 0 then do;
        do m = 1 to dnum(ds);
            fn = dread(ds, m);
            n_files + 1;
            if m <= 3 then do;                       /* keep a few names */
                sample = fn; output _sample;
            end;
            /* must be the TELEPHONY day-and-time file. The OC publication also
               ships a "Submissions via OC Systems By Day and Time" zip, so the
               phrase alone is not enough.                                    */
            if index(upcase(fn), 'CLOUD BASED TELEPHONY') and
               index(upcase(fn), 'DAY AND TIME') and index(upcase(fn), '.CSV') then f_cbtcsv = 1;
            if index(upcase(fn), 'CLOUD BASED TELEPHONY') and
               index(upcase(fn), 'DAY AND TIME') and index(upcase(fn), '.ZIP') then f_cbtzip = 1;
            if index(upcase(fn), 'GP-REG-PAT-PRAC-QUIN-AGE')                   then f_reg    = 1;
            if index(upcase(fn), 'GP-REG-PAT-PRAC-LSOA-ALL')                   then f_lsoa   = 1;
            if index(upcase(fn), 'PRACTICE LEVEL - DETAILED.CSV')              then f_wf     = 1;
            if index(upcase(fn), 'NSPL_') and index(upcase(fn), '.CSV')        then f_nspl   = 1;
            if upcase(fn) = 'EPRACCUR.CSV'                                     then f_ons    = 1;
            if index(upcase(fn), 'SUBMISSIONS VIA OC')                         then f_oc     = 1;
            if index(upcase(fn), 'GPPS_') and index(upcase(fn), 'PRACTICE_DATA') and
               upcase(scan(fn, -1, '.')) = 'CSV'                                then f_gpps   = 1;
            if index(translate(upcase(fn), ' ', '-'), 'CALLS ANSWERED METRIC') and
               upcase(scan(fn, -1, '.')) = 'ZIP'                                then f_cbta   = 1;
        end;
        rc = dclose(ds);
    end;
    rc = filename('SC');
    output _scan;
run;

/*---- the folder scan (_scan) is used below ----*/

/*---- 3. pick one folder per role (shallowest match) --------------------*/
/*  NOTE: PROC SQL does not allow ORDER BY inside an in-line view, which is
    what broke the previous version. ORDER BY goes on the outer query, and
    SELECT INTO with one macro variable keeps the FIRST row.               */
%macro _pick(where=, mvar=);
    %global &mvar;
    %let &mvar = ;
    proc sql noprint;
        select dir into :&mvar trimmed
        from _scan
        where &where
        order by depth, dir;
    quit;
%mend;

%_pick(where=%str(f_cbtcsv=1 or f_cbtzip=1), mvar=CBTDIR);
%_pick(where=%str(f_reg=1),                  mvar=REGDIR);
%_pick(where=%str(f_wf=1),                   mvar=WFDIR);
%_pick(where=%str(f_nspl=1),                 mvar=NSPLDIR);
%_pick(where=%str(f_ons=1),                  mvar=ONSDIR);
%_pick(where=%str(f_oc=1),                   mvar=OCDIR);
%_pick(where=%str(f_gpps=1),                 mvar=GPPSDIR);
%_pick(where=%str(f_cbta=1),                 mvar=CBTADIR);

/* Reissued months: a subfolder of the telephony folder that holds day-and-time CSVs (02_load_raw.sas uses it only
   for the reissued months December 2024 and February, April and June 2025) */
%macro _cbtfix;
    %global CBTFIX; %let CBTFIX = ;
    proc sql noprint;
        select dir into :CBTFIX trimmed
        from _scan
        where f_cbtcsv = 1 and depth >= 2 and dir ne "&CBTDIR"
              and index(upcase(dir), upcase(cats("&CBTDIR", '\'))) = 1
        order by depth, dir;
    quit;
%mend;
%_cbtfix;

/*---- 4. specific files -------------------------------------------------*/
%macro _file(dir=, part=, mvar=);
    %global &mvar; %let &mvar = ;
    %if %superq(dir) = %then %return;
    data _null_;
        length fn $400;
        rc = filename('_f', "&dir"); did = dopen('_f');
        if did = 0 then do; rc = filename('_f'); stop; end;
        do i = 1 to dnum(did);
            fn = dread(did, i);
            if index(upcase(fn), "%upcase(&part)") and upcase(scan(fn, -1, '.')) = 'CSV' then do;
                call symputx("&mvar", catx('\', "&dir", fn), 'G'); leave;
            end;
        end;
        rc = dclose(did); rc = filename('_f');
    run;
%mend;
%_file(dir=&ONSDIR, part=FILE_7_IOD2025, mvar=IOD);
%_file(dir=&ONSDIR, part=EPRACCUR.CSV, mvar=EPRAC);
%_file(dir=&GPPSDIR, part=GPPS_2025_PRACTICE_DATA, mvar=GPPS25);
%_file(dir=&GPPSDIR, part=GPPS_2026_PRACTICE_DATA, mvar=GPPS26);

/*---- 5. output folder --------------------------------------------------*/
%macro _out;
    %global OUTDIR;
    %let OUTDIR = &ROOT.\SAS_OUT;
    %if %sysfunc(fileexist(&OUTDIR)) = 0 %then %do;
        %let _rc = %sysfunc(dcreate(SAS_OUT, &ROOT.));
    %end;
%mend;
%_out;
/* the survey link uses only practices with at least 100 inbound calls in January to March of
   the survey year. SAS_OUT_min100 holds EXT_LINK with the telephony values of practices below the threshold set to
   missing for that wave; every other data set is read from SAS_OUT unchanged (library concatenation, first found wins;
   these programs write nothing to PERM). */
libname permo "&OUTDIR." access=readonly;
%macro _outx;   /* public release: create SAS_OUT_min100 under ROOT if it is missing */
    %if %sysfunc(fileexist(&ROOT.\SAS_OUT_min100)) = 0 %then %do;
        %let _rc = %sysfunc(dcreate(SAS_OUT_min100, &ROOT.));
    %end;
%mend;
%_outx;
libname permx "&ROOT.\SAS_OUT_min100";
libname perm (permx permo);

%let M_FROM = 202410;
%let M_TO   = 202606;

%put NOTE: 00_paths: input folders found.;

/* %fresh - each table starts as in a new SAS session: WORK emptied, the global macro variables set above kept and
   the rest deleted (automatic SYS variables are left alone), options and ODS selection as at start-up. */
proc sql noprint;
    select distinct quote(strip(name)) into :_KEEP separated by ' ' from dictionary.macros where scope = 'GLOBAL';
quit;
%let _KEEP = &_KEEP "_KEEP";
%macro fresh;
    %local _del;
    proc datasets lib=work kill nolist memtype=(data view); quit;
    proc sql noprint;
        select distinct strip(name) into :_del separated by ' ' from dictionary.macros
        where scope = 'GLOBAL' and name not in (&_KEEP) and substr(name, 1, 3) ne 'SYS';
    quit;
    %if %length(&_del) %then %symdel &_del / nowarn;
    options compress=no cmplib=_null_;
    ods select all;
    title; footnote;
%mend;

* PART 2. Tables 1 to 3 ;

/* M_out_txt.sas - shared macros, include only (never run on its own).
   Collect the numbers an exhibit program prints and write them, and nothing else, to output\<program>.txt.
   ASCII only.

   %out_start(prog)          start an empty list; prog = program name (also the .txt name)
   %out_add(data)            append a data set with two character columns: label, value (rows in print order)
   %out_write                write <OUT>\<prog>.txt : one line per number, 'label | value'

   Expression macros for use inside a DATA step (return character values formatted as the paper prints them):
   %fx(x, d)                 x rounded to d decimals; minus zero printed as zero; integers of 10 000 or more
                             with a space as thousands separator (BMJ style, e.g. 12 856)
   %fci(e, l, h, d)          'e (l to h)' with %fx for each part */

%macro fx(x, d);
    ifc(round(&x, 10 ** (-&d)) = 0, strip(put(0, 32.&d)),
        ifc(&d = 0 and abs(&x) >= 9999.5, translate(strip(put(&x, comma32.)), ' ', ','),
            strip(put(&x, 32.&d))))
%mend;
%macro fci(e, l, h, d);
    cat(%fx(&e, &d), ' (', %fx(&l, &d), ' to ', %fx(&h, &d), ')')
%mend;

%macro out_start(prog);
    %global _OUTPROG;
    %let _OUTPROG = &prog;
    data _out_;
        length label $200 value $120;
        stop;
    run;
%mend;

%macro out_add(data);
    data _out_;
        set _out_ &data(keep=label value);
    run;
%mend;

%macro out_write;
    %local f;
    %let f = &OUT.\&_OUTPROG..txt;
    data _null_;
        set _out_;
        length _line $330;
        file "&f" lrecl=400;
        _line = catx(' | ', label, value);
        put _line;
    run;
    %put NOTE: &_OUTPROG - results written to the output folder;
%mend;

* Table 1 (T1_table1) ;
%fresh;

/* T1_table1.sas - Table 1 and the numbers in its footnote.
   Characteristics of general practices with and without practice level telephony data, England, June 2026.
   Derived from: the table program (TABLE 1, FOOTNOTE NUMBERS table 1), analysis program 07 (list size 50 000 or more),
   check program 28 parts 1 and 2 (reported ease row, callback row among non-participants).
   Reads perm (read only). Writes only output\T1_table1.txt. ASCII only. */

* input folders and libraries: set once in PART 1 ;
* M_out_txt macros: defined in PART 2 ;
options validvarname=v7 nodate nonumber;
ods exclude all;

%let T1MONTH = 202606;

/* June 2026 cross-section (the table program X1), with the 2026 survey value (check program 28 part 1) */
proc sql;
    create table _ever as
    select practice_code, max(cbt_observed) as ever_obs, (max(cbt005_cb_requested) > 0) as ever_cb
    from perm.practice_month group by practice_code;
    create table X1 as
    select a.practice_code, a.list_size,
           100 * a.pct_female   as pct_female,
           100 * a.share_0_4    as share_0_4,
           100 * a.share_65plus as share_65plus,
           a.pw_imd_score,
           u.pw_urban_share,
           (a.pw_imd_decile_1poorest = 1) as poorest,
           coalesce(e.ever_cb, 0)  as ever_cb,
           coalesce(e.ever_obs, 0) as ever_obs,
           k.ease_2026,
           a.cbt001_inbound, a.cbt004_missed, a.cbt005_cb_requested,
           case when a.list_size > 0 then 1000 * a.cbt001_inbound / a.list_size end as per1000,
           case when a.cbt001_inbound > 0 then 100 * a.cbt004_missed / a.cbt001_inbound end as aband_pct,
           case when a.cbt001_inbound > 0
                then 100 * (a.cbt004_missed + a.cbt005_cb_requested) / a.cbt001_inbound end as rtnc_pct,
           (a.cbt_observed = 1) as part
    from perm.practice_month(where=(month = "&T1MONTH.")) a
         left join perm.pw_urban u on a.practice_code = u.practice_code
         left join _ever         e on a.practice_code = e.practice_code
         left join perm.ext_link k on a.practice_code = k.practice_code;
quit;

/* medians and quartiles (PROC MEANS default definition, as the table program and check program 28) */
%macro med(var=, dp=, ord=, item=, ponly=0);
    proc means data=X1 noprint nway;
        %if &ponly = 1 %then %do; where part = 1; %end;
        class part; var &var;
        output out=_m(drop=_type_ _freq_) median=med q1=q1 q3=q3;
    run;
    data _r;
        length label $200 value $120;
        set _m;
        ord = &ord + (1 - part) / 10;
        label = catx(' | ', 'Table 1', "&item", ifc(part = 1, 'With practice level data', 'Without'));
        value = %fci(med, q1, q3, &dp);
        keep ord label value;
    run;
    proc append base=_t1 data=_r force; run;
%mend;
proc datasets lib=work nolist; delete _t1; quit;
%med(var=list_size,      dp=0, ord=3,  item=%str(Registered list size, median (IQR)));
%med(var=pct_female,     dp=1, ord=4,  item=%str(Female patients, %%, median (IQR)));
%med(var=share_0_4,      dp=1, ord=5,  item=%str(Patients aged 0 to 4 years, %%, median (IQR)));
%med(var=share_65plus,   dp=1, ord=6,  item=%str(Patients aged 65 or over, %%, median (IQR)));
%med(var=pw_imd_score,   dp=1, ord=7,  item=%str(Patient weighted deprivation score (2025), median (IQR)));
%med(var=ease_2026,      dp=1, ord=8,  item=%str(Patients finding phone contact easy (2026 survey), %%, median (IQR)));
%med(var=cbt001_inbound, dp=0, ord=11, item=%str(Monthly inbound calls, median (IQR)), ponly=1);
%med(var=per1000,        dp=0, ord=12, item=%str(Inbound calls per 1000 registered patients, median (IQR)), ponly=1);
%med(var=aband_pct,      dp=1, ord=13, item=%str(Abandonment, %% of calls, median (IQR)), ponly=1);
%med(var=rtnc_pct,       dp=1, ord=14, item=%str(Real time non-connection, %% of calls, median (IQR)), ponly=1);

/* counts: group sizes, most deprived tenth, callback use */
proc sql;
    create table _c as
    select part, count(*) as n, sum(poorest) as n_poor, 100 * mean(poorest) as p_poor,
           sum(ever_cb) as n_cb, 100 * mean(ever_cb) as p_cb,
           sum(ever_obs) as n_obs, sum(ever_obs * ever_cb) as n_obs_cb,
           sum(ease_2026 ne .) as n_ease,
           mean(list_size) as mean_ls,
           100 * sum(list_size > . and list_size < 1000) / sum(list_size > .) as p_u1000,
           100 * sum(list_size >= 50000) / sum(list_size > .)                as p_50k,
           1000 * sum(cbt001_inbound) / sum(list_size) as agg_per1000,
           100 * sum(cbt004_missed) / sum(cbt001_inbound) as agg_A,
           100 * sum(cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound) as agg_B
    from X1 group by part;
    create table _u as
    select part, sum(pw_urban_share * list_size) / sum(list_size) as urban
    from X1 where pw_urban_share is not missing group by part;
quit;
data _r;
    length label $200 value $120 g $40;
    merge _c _u; by part;
    g = ifc(part = 1, 'With practice level data', 'Without');
    ord = 1 + (1 - part) / 10; label = catx(' | ', 'Table 1', 'header', g, 'n'); value = %fx(n, 0); output;
    ord = 9 + (1 - part) / 10; label = catx(' | ', 'Table 1 | In most deprived tenth, No (%)', g);
        value = cat(%fx(n_poor, 0), ' (', %fx(p_poor, 1), ')'); output;
    ord = 10 + (1 - part) / 10; label = catx(' | ', 'Table 1 | Ever recorded callback use, No (%)', g);
        if part = 1 then value = cat(%fx(n_cb, 0), ' (', %fx(p_cb, 1), ')');
        else value = cat(%fx(n_obs_cb, 0), ' of ', %fx(n_obs, 0), ' (', %fx(100 * n_obs_cb / n_obs, 1), ')');
        output;
    ord = 21 + (1 - part) / 10; label = catx(' | ', 'Table 1 footnote | mean list size', g); value = %fx(mean_ls, 0); output;
    ord = 22 + (1 - part) / 10; label = catx(' | ', 'Table 1 footnote | under 1000 registered patients, %', g); value = %fx(p_u1000, 1); output;
    ord = 23 + (1 - part) / 10; label = catx(' | ', 'Table 1 footnote | 50 000 or more registered patients, %', g); value = %fx(p_50k, 1); output;
    ord = 24 + (1 - part) / 10; label = catx(' | ', 'Table 1 footnote | practices with 2026 GP Patient Survey results', g); value = %fx(n_ease, 0); output;
    if part = 1 then do;
        ord = 25; label = 'Table 1 footnote | call weighted abandonment, participants, June 2026, %'; value = %fx(agg_A, 1); output;
        ord = 26; label = 'Table 1 footnote | call weighted real time non-connection, participants, June 2026, %'; value = %fx(agg_B, 1); output;
        ord = 27; label = 'Table 1 footnote | aggregate inbound calls per 1000 registered patients'; value = %fx(agg_per1000, 0); output;
    end;
    ord = 28 + (1 - part) / 10; label = catx(' | ', 'Table 1 footnote | registered patients living in an urban LSOA, %', g); value = %fx(urban, 1); output;
    keep ord label value;
run;
proc append base=_t1 data=_r force; run;
proc sort data=_t1; by ord; run;

%out_start(T1_table1);
%out_add(_t1);
%out_write;

* Table 2 (and table S10) (T2_table2) ;
%fresh;

/* T2_table2.sas - Table 2 (panels A and B) and the numbers in its footnote.
   Variation between practices in patient reported ease of phone contact explained by five definitions of a failed call
   and three waiting time measures, GP Patient Survey 2025 and 2026 linked to telephony for January to March.
   Derived from:
     panel A  the table program (TABLE 2 PANEL 1: weighted R2 and HC1 slopes; FOOTNOTE NUMBERS: national levels over the
              21 months) and check program 23 part C (bootstrap intervals for R2 and differences in R2,
              2000 practice resamples, seed 20261002)
     panel B  check program 29 (durations publication, common sample, bootstrap 2000 practice resamples,
              seed 20261006) and check program 25b part 1c (slopes on the same sample); the footnote
              differences R2(total non-connection) - R2(waiting > 2 min) and - R2(waiting > 5 min) are percentiles of the
              same replicates (check program 25b part 1d and check program 25c 7-1 used the same seed and sample)
     footnote practices without 2025 telephony and in both waves; the link without the 100 call rule (perm library
              SAS_OUT only, as the copy of this check run from the unrestricted survey link run)
   Reads perm and the durations csv files (read only). Writes only output\T2_table2.txt. ASCII only. */

* input folders and libraries: set once in PART 1 ;
* M_out_txt macros: defined in PART 2 ;
* from M_wls_hc1.sas ;
/* M_wls_hc1.sas - shared macro, include only (never run on its own).
   Copied without change from the table program (%wls), the estimator behind the published survey link numbers:
   weighted least squares with an intercept, HC1 heteroscedasticity consistent standard errors, weighted R2.
   USAGE  %wls(data=, y=, x=, w=, out=, tag=)   x = up to 12 regressors
   OUT    tag var coef se t r2 n   (one row per regressor, first row Intercept)
   ASCII only. */

%macro wls(data=, y=, x=, w=, out=, tag=);
    %local k p i;
    %let k = %sysfunc(countw(&x)); %let p = %eval(&k + 1);
    data _w1;
        set &data;
        where &y ne . and &w ne . and &w > 0
        %do i = 1 %to &k; and %scan(&x, &i) ne . %end; ;
        keep &y &x &w;
    run;
    /* pass 1: X'WX, X'Wy */
    data _xtx(keep=i j v) _xty(keep=i v) _n(keep=n ybar sw);
        set _w1 end=eof;
        array xv{&p} _temporary_;
        array A{&p, &p} _temporary_;
        array b{&p} _temporary_;
        if _n_ = 1 then do;                      /* temporary arrays start missing: zero them */
            do i = 1 to &p; b{i} = 0; do j = 1 to &p; A{i, j} = 0; end; end;
        end;
        xv{1} = 1;
        %do i = 1 %to &k; xv{%eval(&i + 1)} = %scan(&x, &i); %end;
        do i = 1 to &p;
            b{i} = b{i} + &w * xv{i} * &y;
            do j = 1 to &p; A{i, j} = A{i, j} + &w * xv{i} * xv{j}; end;
        end;
        n + 1; sw + &w; swy + &w * &y;
        if eof then do;
            ybar = swy / sw;
            do i = 1 to &p;
                v = b{i}; output _xty;
                do j = 1 to &p; v = A{i, j}; output _xtx; end;
            end;
            output _n;
        end;
    run;
    /* invert A by Gauss-Jordan, beta = Ainv b */
    data _inv(keep=i j v) _beta(keep=i beta);
        array A{&p, &p} _temporary_; array b{&p} _temporary_;
        array Inv{&p, &p} _temporary_;
        do until (e1); set _xtx end=e1; A{i, j} = v; end;
        do until (e2); set _xty end=e2; b{i} = v; end;
        do i = 1 to &p; do j = 1 to &p; Inv{i, j} = (i = j); end; end;
        do c = 1 to &p;
            piv = A{c, c};
            if abs(piv) < 1e-12 then do; put "ERROR: singular X'WX in wls &tag"; abort cancel; end;
            do j = 1 to &p; A{c, j} = A{c, j} / piv; Inv{c, j} = Inv{c, j} / piv; end;
            do r = 1 to &p; if r ne c then do;
                f = A{r, c};
                do j = 1 to &p; A{r, j} = A{r, j} - f * A{c, j}; Inv{r, j} = Inv{r, j} - f * Inv{c, j}; end;
            end; end;
        end;
        do i = 1 to &p;
            beta = 0; do j = 1 to &p; beta = beta + Inv{i, j} * b{j}; end; output _beta;
            do j = 1 to &p; v = Inv{i, j}; output _inv; end;
        end;
        stop;
    run;
    /* pass 2: residuals, HC1 meat, weighted R2 */
    data _meat(keep=i j v) _fit(keep=r2);
        array xv{&p} _temporary_; array bt{&p} _temporary_;
        array M{&p, &p} _temporary_;
        if _n_ = 1 then do;
            do until (e1); set _beta end=e1; bt{i} = beta; end;
            set _n;
            do i = 1 to &p; do j = 1 to &p; M{i, j} = 0; end; end;
        end;
        set _w1 end=eof;
        xv{1} = 1;
        %do i = 1 %to &k; xv{%eval(&i + 1)} = %scan(&x, &i); %end;
        yhat = 0; do i = 1 to &p; yhat = yhat + bt{i} * xv{i}; end;
        e = &y - yhat;
        rss + &w * e * e; tss + &w * (&y - ybar) ** 2;
        do i = 1 to &p; do j = 1 to &p; M{i, j} = M{i, j} + (&w * e) ** 2 * xv{i} * xv{j}; end; end;
        if eof then do;
            r2 = 1 - rss / tss; output _fit;
            do i = 1 to &p; do j = 1 to &p; v = M{i, j}; output _meat; end; end;
        end;
    run;
    data &out(keep=tag var coef se t r2 n);
        length tag $40 var $32;
        array Inv{&p, &p} _temporary_; array M{&p, &p} _temporary_; array Vc{&p, &p} _temporary_;   /* not 'V': clashes with variable v */
        array bt{&p} _temporary_;
        do until (e1); set _inv end=e1; Inv{i, j} = v; end;
        do until (e2); set _meat end=e2; M{i, j} = v; end;
        do until (e3); set _beta end=e3; bt{i} = beta; end;
        set _n; set _fit;
        /* V = Inv M Inv * n/(n-p) */
        do i = 1 to &p; do j = 1 to &p;
            s = 0;
            do a = 1 to &p; do c = 1 to &p; s = s + Inv{i, a} * M{a, c} * Inv{c, j}; end; end;
            Vc{i, j} = s * n / (n - &p);
        end; end;
        tag = "&tag";
        var = 'Intercept'; coef = bt{1}; se = sqrt(Vc{1, 1}); t = coef / se; output;
        %do i = 1 %to &k;
            var = "%scan(&x, &i)"; coef = bt{%eval(&i + 1)}; se = sqrt(Vc{%eval(&i + 1), %eval(&i + 1)}); t = coef / se; output;
        %end;
        stop;
    run;
%mend;
* end of M_wls_hc1.sas ;
options validvarname=v7 nodate nonumber compress=yes;
ods exclude all;

%let NBOOT = 2000;


/* PANEL A ------------------------------------------------------------------------------------------------------- */

/* LK: survey link, W as the sum of the three components (the table program) */
data LKA;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
run;

/* weighted R2 and HC1 slopes, one definition at a time (the table program %r2def) */
%macro r2def(yr, tag, out);
    %local d v;
    data _s; set LKA; where A_&tag ne . and ease_&yr ne .; run;
    %do d = 1 %to 5;
        %let v = %scan(A B As Bs W, &d);
        %wls(data=_s, y=ease_&yr, x=&v._&tag, w=n_eval_&yr, out=_o&d, tag=&v);
        data _o&d; set _o&d; where var ne 'Intercept'; run;
    %end;
    data &out; length wave $4; set _o1-_o5; wave = "&yr"; run;
%mend;
%r2def(2025, w25, _pa25);
%r2def(2026, w26, _pa26);
data PA; set _pa25 _pa26; run;

/* bootstrap intervals for R2 and R2(definition) - R2(A) (check program 23 part C, unchanged) */
%macro r2boot(yr, tag);
    data _r&yr;
        set perm.ext_link;
        where A_&tag ne . and ease_&yr ne . and n_eval_&yr > 0;
        W_&tag = A_&tag + cb_&tag + menu_&tag;
        keep practice_code ease_&yr n_eval_&yr A_&tag B_&tag As_&tag Bs_&tag W_&tag;
    run;
    proc surveyselect data=_r&yr out=_rb&yr method=urs samprate=1 reps=2000
                      seed=20261002 outhits noprint;
    run;
    data _rb&yr; set _r&yr(in=o) _rb&yr; if o then replicate = 0; run;
    %local d v;
    %do d = 1 %to 5;
        %let v = %scan(A B As Bs W, &d);
        proc sql;
            create table _q&d as
            select replicate,
                   ( sum(n_eval_&yr * &v._&tag * ease_&yr) / sum(n_eval_&yr)
                     - (sum(n_eval_&yr * &v._&tag) / sum(n_eval_&yr)) * (sum(n_eval_&yr * ease_&yr) / sum(n_eval_&yr)) ) ** 2
                   / ( ( sum(n_eval_&yr * &v._&tag ** 2) / sum(n_eval_&yr) - (sum(n_eval_&yr * &v._&tag) / sum(n_eval_&yr)) ** 2 )
                     * ( sum(n_eval_&yr * ease_&yr ** 2) / sum(n_eval_&yr) - (sum(n_eval_&yr * ease_&yr) / sum(n_eval_&yr)) ** 2 ) )
                   as R2_&v
            from _rb&yr where &v._&tag ne .
            group by replicate;
        quit;
    %end;
    data _q&yr;
        merge _q1 _q2 _q3 _q4 _q5; by replicate;
        dB = R2_B - R2_A; dAs = R2_As - R2_A; dBs = R2_Bs - R2_A; dW = R2_W - R2_A;
    run;
    proc univariate data=_q&yr(where=(replicate > 0)) noprint;
        var R2_A R2_B R2_As R2_Bs R2_W dB dAs dBs dW;
        output out=_qci&yr pctlpts=2.5 97.5
               pctlpre=A_ B_ As_ Bs_ W_ dB_ dAs_ dBs_ dW_;
    run;
%mend;
%r2boot(2025, w25);
%r2boot(2026, w26);

/* national level of each definition over the 21 months, all hours (the table program FOOTNOTE NUMBERS) */
proc sql;
    create table NAT as
    select 100 * sum(cbt004_missed) / sum(cbt001_inbound)                                          as A,
           100 * sum(cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound)                    as B,
           100 * sum(cbt004_missed) / sum(cbt001_inbound - cbt002_ivr_ended)                       as As,
           100 * sum(cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound - cbt002_ivr_ended) as Bs,
           100 * sum(cbt002_ivr_ended + cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound) as W
    from perm.practice_month where cbt_observed = 1;
quit;

/* panel A rows */
data TA;
    length label $200 value $120 def $60;
    if _n_ = 1 then do;
        set NAT(rename=(A=nA B=nB As=nAs Bs=nBs W=nW));
        set _q2025(where=(replicate = 0) rename=(dB=e25B dAs=e25As dBs=e25Bs dW=e25W) keep=replicate dB dAs dBs dW);
        set _q2026(where=(replicate = 0) rename=(dB=e26B dAs=e26As dBs=e26Bs dW=e26W) keep=replicate dB dAs dBs dW);
        set _qci2025(rename=(A_2_5=a25A_l A_97_5=a25A_h B_2_5=a25B_l B_97_5=a25B_h As_2_5=a25As_l As_97_5=a25As_h
                             Bs_2_5=a25Bs_l Bs_97_5=a25Bs_h W_2_5=a25W_l W_97_5=a25W_h
                             dB_2_5=d25B_l dB_97_5=d25B_h dAs_2_5=d25As_l dAs_97_5=d25As_h
                             dBs_2_5=d25Bs_l dBs_97_5=d25Bs_h dW_2_5=d25W_l dW_97_5=d25W_h));
        set _qci2026(rename=(A_2_5=a26A_l A_97_5=a26A_h B_2_5=a26B_l B_97_5=a26B_h As_2_5=a26As_l As_97_5=a26As_h
                             Bs_2_5=a26Bs_l Bs_97_5=a26Bs_h W_2_5=a26W_l W_97_5=a26W_h
                             dB_2_5=d26B_l dB_97_5=d26B_h dAs_2_5=d26As_l dAs_97_5=d26As_h
                             dBs_2_5=d26Bs_l dBs_97_5=d26Bs_h dW_2_5=d26W_l dW_97_5=d26W_h));
    end;
    array nat{5}  nA nB nAs nBs nW;
    array r25l{5} a25A_l a25B_l a25As_l a25Bs_l a25W_l;   array r25h{5} a25A_h a25B_h a25As_h a25Bs_h a25W_h;
    array r26l{5} a26A_l a26B_l a26As_l a26Bs_l a26W_l;   array r26h{5} a26A_h a26B_h a26As_h a26Bs_h a26W_h;
    array e25{5}  _e25A e25B e25As e25Bs e25W;            array e26{5}  _e26A e26B e26As e26Bs e26W;
    array d25l{5} _d25A_l d25B_l d25As_l d25Bs_l d25W_l;  array d25h{5} _d25A_h d25B_h d25As_h d25Bs_h d25W_h;
    array d26l{5} _d26A_l d26B_l d26As_l d26Bs_l d26W_l;  array d26h{5} _d26A_h d26B_h d26As_h d26Bs_h d26W_h;
    merge PA(where=(wave = '2025') keep=wave tag r2 coef se n rename=(r2=r25 coef=b25 se=s25 n=n25))
          PA(where=(wave = '2026') keep=wave tag r2 coef se n rename=(r2=r26 coef=b26 se=s26 n=n26));
    k = whichc(tag, 'A', 'B', 'As', 'Bs', 'W');
    def = scan('Abandonment (published measure)|Real time non-connection (+ callback)|Queue restricted abandonment|'
               || 'Queue restricted non-connection|Total non-connection (+ menu ended)', k, '|');
    if k = 1 then do;
        ord = 1; label = 'Table 2 | Panel A: all linked practices | practices in 2025'; value = %fx(n25, 0); output;
        ord = 2; label = 'Table 2 | Panel A: all linked practices | practices in 2026'; value = %fx(n26, 0); output;
    end;
    ord = 10 * k;
    label = catx(' | ', 'Table 2 | Panel A', def, 'national level over the 21 month series, % of calls');
        value = %fx(nat{k}, 1); output;
    ord + 1; label = catx(' | ', 'Table 2 | Panel A', def, 'R2 2025 (95% CI)');
        value = %fci(r25, r25l{k}, r25h{k}, 2); output;
    ord + 1; label = catx(' | ', 'Table 2 | Panel A', def, 'R2 2026 (95% CI)');
        value = %fci(r26, r26l{k}, r26h{k}, 2); output;
    if k > 1 then do;
        ord + 1; label = catx(' | ', 'Table 2 | Panel A', def, 'difference from abandonment, 2025 (95% CI)');
            value = %fci(e25{k}, d25l{k}, d25h{k}, 2); output;
        ord + 1; label = catx(' | ', 'Table 2 | Panel A', def, 'difference from abandonment, 2026 (95% CI)');
            value = %fci(e26{k}, d26l{k}, d26h{k}, 2); output;
    end;
    ord + 1; label = catx(' | ', 'Table 2 | Panel A', def, 'slope 2025 (95% CI)');
        value = %fci(b25, b25 - 1.96 * s25, b25 + 1.96 * s25, 2); output;
    ord + 1; label = catx(' | ', 'Table 2 | Panel A', def, 'slope 2026 (95% CI)');
        value = %fci(b26, b26 - 1.96 * s26, b26 + 1.96 * s26, 2); output;
    if tag = 'As' then do;
        ord = 70; label = 'Table 2 footnote | practices used by the two queue restricted definitions in 2026';
        value = %fx(n26, 0); output;
    end;
    keep ord label value;
run;


/* PANEL B (check program 29, with the slopes of check program 25b part 1c) --------------------------------------------------------- */
%let SEED = 20261006;

data LK;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
    length pcl $10;
    pcl = coalescec(pcn_code, practice_code);
run;
proc sort data=LK; by practice_code; run;

%macro readdur(mon, yr, tag);
    %local r rg;
    %do r = 1 %to 7;
        %let rg = %scan(Y56 Y58 Y59 Y60 Y61 Y62 Y63, &r);
        data _d;
            length practice $10 indicator $10 dur $12;
            infile "&CBTDIR.\Cloud Based Telephony By Durations - &mon. &yr._&rg..csv" dsd truncover firstobs=2 lrecl=2048;
            input dt : yymmdd10. region_code : $10. icb : $20. sub_icb : $20. pcn : $20. practice $ indicator $ dur $ value;
            if missing(value) then value = 0;
            if practice = 'Unassigned' then delete;   /* shared-account calls, as PERM.DT_ALL */
            keep practice indicator dur value;
        run;
        proc sql;
            create table _a as
            select practice,
                   sum(case when indicator='CBT001' then value else 0 end) as inb,
                   sum(case when indicator='CBT003' then value else 0 end) as ans,
                   sum(case when indicator='CBT003' and dur in ('121_180','181_240','241_300','>300') then value else 0 end) as ans120,
                   sum(case when indicator='CBT003' and dur = '>300' then value else 0 end) as ans300,
                   sum(case when indicator='CBT004' then value else 0 end) as mis,
                   sum(case when indicator='CBT004' and dur in ('121_180','181_240','241_300','>300') then value else 0 end) as mis120
            from _d group by practice;
        quit;
        data _a; length wave $3 mon $16; set _a; wave = "&tag"; mon = "&mon.&yr"; run;
        proc append base=DUR data=_a force; run;
    %end;
%mend;
proc datasets lib=work nolist; delete DUR; quit;
%readdur(January,  2025, w25); %readdur(February, 2025, w25); %readdur(March, 2025, w25);
%readdur(January,  2026, w26); %readdur(February, 2026, w26); %readdur(March, 2026, w26);
proc sql;
    create table DURP as
    select practice as practice_code length=10, wave,
           sum(inb) as inb, sum(ans) as ans, sum(ans120) as ans120, sum(ans300) as ans300, sum(mis120) as mis120
    from DUR group by practice, wave;
quit;
data DURP; set DURP;
    if ans > 0 then do; L2 = 100 * ans120 / ans; L5 = 100 * ans300 / ans; end;
    if inb > 0 then M2 = 100 * mis120 / inb;
run;
proc sql;
    create table LKD as
    select a.*, b.L2 as L2_w25, b.L5 as L5_w25, b.M2 as M2_w25, c.L2 as L2_w26, c.L5 as L5_w26, c.M2 as M2_w26
    from LK a left join DURP(where=(wave='w25')) b on a.practice_code = b.practice_code
              left join DURP(where=(wave='w26')) c on a.practice_code = c.practice_code;
quit;

%macro r2set(yr, tag);
    data _s&tag; set LKD;
        where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne . and W_&tag ne . and L2_&tag ne .
          and L5_&tag ne . and M2_&tag ne .;
        y = ease_&yr; w = n_eval_&yr; xA = A_&tag; xW = W_&tag; L2 = L2_&tag; L5 = L5_&tag; M2 = M2_&tag;
        keep practice_code y w xA xW L2 L5 M2;
    run;
%mend;
%r2set(2025, w25);
%r2set(2026, w26);

%macro fits(in=, out=, by=);
    %local m;
    %do m = 1 %to 6;
        proc reg data=&in outest=_e&m(keep=&by _RSQ_) rsquare noprint;
            %if %length(&by) > 0 %then %do; by &by; %end;
            weight w;
            %if &m = 1 %then %do; model y = xA; %end;
            %if &m = 2 %then %do; model y = xW; %end;
            %if &m = 3 %then %do; model y = L2; %end;
            %if &m = 4 %then %do; model y = L5; %end;
            %if &m = 5 %then %do; model y = M2; %end;
            %if &m = 6 %then %do; model y = xW L2; %end;
        run; quit;
        data _e&m; set _e&m; rename _RSQ_ = r&m; run;
    %end;
    data &out; merge _e1 _e2 _e3 _e4 _e5 _e6 %if %length(&by) > 0 %then %do; ; by &by %end; ;
        d_L2_A = r3 - r1; d_L5_A = r4 - r1; d_M2_A = r5 - r1; d_WL_A = r6 - r1; d_W_A = r2 - r1;
        d_W_L2 = r2 - r3; d_W_L5 = r2 - r4;
    run;
%mend;

%macro r2boot(tag, yr);
    %fits(in=_s&tag, out=_pt&tag, by=);
    proc surveyselect data=_s&tag out=_b&tag method=urs samprate=1 reps=&NBOOT outhits seed=&SEED noprint; run;
    %fits(in=_b&tag, out=_bd&tag, by=Replicate);
    proc univariate data=_bd&tag noprint;
        var r1 r2 r3 r4 r5 r6 d_L2_A d_L5_A d_M2_A d_WL_A d_W_A d_W_L2 d_W_L5;
        output out=_bx&tag pctlpts=2.5 97.5
               pctlpre=pA_ pW_ pL2_ pL5_ pM2_ pWL_ dL2A_ dL5A_ dM2A_ dWLA_ dWA_ dWL2_ dWL5_;
    run;
    /* slopes on the same sample (check program 25b part 1c) */
    %local d v;
    %do d = 1 %to 5;
        %let v = %scan(xA xW L2 L5 M2, &d);
        %wls(data=_s&tag, y=y, x=&v, w=w, out=_sl&d, tag=&v);
    %end;
    data _sl&tag; length wave $4; set _sl1-_sl5; where var ne 'Intercept'; wave = "&yr"; run;
    data _pt&tag; length wave $4; set _pt&tag; wave = "&yr"; run;
    data _bx&tag; length wave $4; set _bx&tag; wave = "&yr"; run;
%mend;
%r2boot(w25, 2025);
%r2boot(w26, 2026);

data TB;
    length label $200 value $120 def $80 yr $4;
    set _ptw25(in=a) _ptw26;
    if a then set _bxw25; else set _bxw26;
    yr = ifc(a, '2025', '2026');
    array pt{6}  r1-r6;
    array lo{6}  pA_2_5  pW_2_5  pL2_2_5  pL5_2_5  pM2_2_5  pWL_2_5;
    array hi{6}  pA_97_5 pW_97_5 pL2_97_5 pL5_97_5 pM2_97_5 pWL_97_5;
    array dp{6}  _dA   d_W_A    d_L2_A    d_L5_A    d_M2_A    d_WL_A;
    array dl{6}  _dAl  dWA_2_5  dL2A_2_5  dL5A_2_5  dM2A_2_5  dWLA_2_5;
    array dh{6}  _dAh  dWA_97_5 dL2A_97_5 dL5A_97_5 dM2A_97_5 dWLA_97_5;
    do k = 1 to 6;
        def = scan('Abandonment|Total non-connection|Answered calls waiting more than 2 min|'
                   || 'Answered calls waiting more than 5 min|Calls abandoned after waiting more than 2 min, % of inbound calls|'
                   || 'Total non-connection plus answered calls waiting more than 2 min', k, '|');
        ord = 100 + 10 * k + (yr = '2026') * 2;
        label = catx(' | ', 'Table 2 | Panel B', def, catx(' ', 'R2', yr, '(95% CI)'));
            value = %fci(pt{k}, lo{k}, hi{k}, 2); output;
        if k > 1 then do;
            ord = ord + 4;
            label = catx(' | ', 'Table 2 | Panel B', def, catx(' ', 'difference from abandonment,', yr, '(95% CI)'));
            value = %fci(dp{k}, dl{k}, dh{k}, 2); output;
        end;
    end;
    ord = 190 + (yr = '2026');
    label = catx(' | ', 'Table 2 footnote | R2 of total non-connection minus that of the share waiting more than 2 min', catx(' ', yr, '(95% CI)'));
        value = %fci(d_W_L2, dWL2_2_5, dWL2_97_5, 2); output;
    ord = 192 + (yr = '2026');
    label = catx(' | ', 'Table 2 footnote | R2 of total non-connection minus that of the share waiting more than 5 min', catx(' ', yr, '(95% CI)'));
        value = %fci(d_W_L5, dWL5_2_5, dWL5_97_5, 2); output;
    keep ord label value;
run;
data TBS;
    length label $200 value $120 def $80;
    set _slw25 _slw26;
    k = whichc(tag, 'xA', 'xW', 'L2', 'L5', 'M2');
    def = scan('Abandonment|Total non-connection|Answered calls waiting more than 2 min|'
               || 'Answered calls waiting more than 5 min|Calls abandoned after waiting more than 2 min, % of inbound calls', k, '|');
    ord = 100 + 10 * k + 8 + (wave = '2026');
    if k = 1 then do;
        o2 = ord; ord = 100 + (wave = '2026');
        label = catx(' ', 'Table 2 | Panel B: practices with waiting time data | practices in', wave);
        value = %fx(n, 0); output;
        ord = o2;
    end;
    label = catx(' | ', 'Table 2 | Panel B', def, catx(' ', 'slope', wave, '(95% CI)'));
    value = %fci(coef, coef - 1.96 * se, coef + 1.96 * se, 2); output;
    keep ord label value;
run;


/* FOOTNOTE: waves, and the link without the 100 call rule ------------------------------------------------------------ */
proc sql;
    create table FN as
    select sum(A_w26 ne . and ease_2026 ne . and A_w25 = .) as n26_no25tel,
           sum(A_w26 ne . and ease_2026 ne . and A_w25 ne . and ease_2025 ne .) as n_both
    from perm.ext_link;
    create table FN2 as
    select (select count(*) from permo.ext_link where A_w25 ne . and ease_2025 ne .)
         - (select count(*) from perm.ext_link  where A_w25 ne . and ease_2025 ne .) as n_dropped25
    from FN;
quit;
data _full; set permo.ext_link; where A_w25 ne . and ease_2025 ne .; run;
%wls(data=_full, y=ease_2025, x=A_w25, w=n_eval_2025, out=_fullA, tag=A full link);
data TF;
    length label $200 value $120;
    set FN; set FN2; set _fullA(where=(var ne 'Intercept'));
    ord = 200; label = 'Table 2 footnote | practices in the 2026 wave without 2025 telephony'; value = %fx(n26_no25tel, 0); output;
    ord = 201; label = 'Table 2 footnote | practices in both waves'; value = %fx(n_both, 0); output;
    ord = 202; label = 'Table 2 footnote | practices not linked in 2025 (fewer than 100 inbound calls in January to March)';
        value = %fx(n_dropped25, 0); output;
    ord = 203; label = 'Table 2 footnote | with that practice, R2 of abandonment in 2025'; value = %fx(r2, 2); output;
    keep ord label value;
run;

data T2; set TA TB TBS TF; run;
proc sort data=T2; by ord; run;

%out_start(T2_table2);
%out_add(T2);
%out_write;

* Table 3 (T3_table3) ;
%fresh;

/* T3_table3.sas - Table 3 (panels A and B) and the numbers in its footnote.
   Rate ratios for failed calls by time cell and by type of day, within the same practice and month.
   Derived from: the table program (TABLE 3 PANEL A, TABLE 3 PANEL B; the pre-opening row of panel A gives the footnote
   call count) and check program 28 part 3 (practices and calendar days behind each panel).
   Model: %fe_cr0 (M_fe_cr0.sas), log rate weighted least squares, practice month fixed effect, weights = calls,
   standard errors clustered by practice (panel A) or by calendar day (panel B).
   Reads perm (read only). Writes only output\T3_table3.txt. ASCII only. */

* input folders and libraries: set once in PART 1 ;
* M_out_txt macros: defined in PART 2 ;
* from M_fe_cr0.sas ;
/* M_fe_cr0.sas - shared macro, include only (never run on its own).
   Copied without change from the estimator used for the published numbers (07_estimator.sas, %fe_cr0):
   log(numerator/denominator) = group dummies + fixed effect (gid) + error, weighted by the denominator,
   fixed effect removed by weighted within-group demeaning, cluster-robust (CR0) standard errors clustered by cid.
   Rows with numerator 0 drop out (log undefined).
   USAGE  %fe_cr0(data=, num=, den=, grp=, ref=, levels=, gid=, cid=, out=, label=)
   OUT    model level rr lcl ucl se n_obs n_clust
   ASCII only. */

%macro fe_cr0(data=, num=, den=, grp=, ref=, levels=, gid=, cid=,
              out=, label=);

    %local k kk i _DL _ML _SL _IN;
    %let k  = %sysfunc(countw(&levels));
    %let kk = %eval(&k * &k);
    %let _DL = ; %let _ML = ; %let _SL = ;
    %do i = 1 %to &k;
        %let _DL = &_DL d&i;
        %let _ML = &_ML md&i;
        %let _SL = &_SL s&i;
    %end;
    %let _IN = "&ref";
    %do i = 1 %to &k;
        %let _IN = &_IN, "%scan(&levels, &i)";
    %end;

    /*---- 1. y, weight, dummies; drop rows the log cannot take ----------*/
    data _fe0;
        set &data;
        length _g $60 _c $60;
        _num = &num;
        _den = &den;
        if _den > 0 and _num > 0;
        if &grp in (&_IN);
        y  = log(_num / _den);
        w  = _den;
        _g = &gid;
        _c = &cid;
        array d{&k} &_DL;
        do _j = 1 to &k; d{_j} = 0; end;
        %do i = 1 %to &k;
            if &grp = "%scan(&levels, &i)" then d&i = 1;
        %end;
        keep y w _g _c &_DL;
    run;

    proc sql noprint;
        select count(*), count(distinct _c) into :_nobs trimmed, :_ncl trimmed
        from _fe0;
    quit;

    /*---- 2. remove the practice-month fixed effect (weighted) ----------*/
    proc means data=_fe0 noprint nway;
        class _g;
        weight w;
        var y &_DL;
        output out=_gm(keep=_g my &_ML) mean(y &_DL) = my &_ML;
    run;
    proc sort data=_fe0; by _g; run;
    data _fe1;
        merge _fe0(in=a) _gm;
        by _g;
        array d{&k} &_DL;
        array m{&k} &_ML;
        y = y - my;
        do _j = 1 to &k; d{_j} = d{_j} - m{_j}; end;
        drop my &_ML _j;
    run;

    /*---- 3. accumulate X'WX and X'Wy ----------------------------------*/
    data _xtx(keep=a1-a&kk b1-b&k);
        set _fe1 end=_eof;
        array d{&k} &_DL;
        array A{&k,&k} a1-a&kk;
        array B{&k} b1-b&k;
        retain a1-a&kk b1-b&k 0;
        do _r = 1 to &k;
            B{_r} + w * d{_r} * y;
            do _c2 = 1 to &k;
                A{_r,_c2} + w * d{_r} * d{_c2};
            end;
        end;
        if _eof then output;
    run;

    /*---- 4. Gauss-Jordan: beta and (X'WX)^-1 --------------------------*/
    data _beta(keep=beta1-beta&k) _ainv(keep=v1-v&kk);
        set _xtx;
        array A{&k,&k} a1-a&kk;
        array B{&k} b1-b&k;
        array Iv{&k,&k} _temporary_;
        array V{&k,&k} v1-v&kk;
        array bt{&k} beta1-beta&k;
        do r = 1 to &k;
            do c = 1 to &k; Iv{r,c} = (r = c); end;
        end;
        do p = 1 to &k;
            piv = A{p,p};
            if abs(piv) < 1e-10 then do;
                put "ERROR: singular design matrix in fe_cr0 (&label)";
                abort cancel;
            end;
            do c = 1 to &k;
                A{p,c}  = A{p,c}  / piv;
                Iv{p,c} = Iv{p,c} / piv;
            end;
            B{p} = B{p} / piv;
            do r = 1 to &k;
                if r ne p then do;
                    f = A{r,p};
                    do c = 1 to &k;
                        A{r,c}  = A{r,c}  - f * A{p,c};
                        Iv{r,c} = Iv{r,c} - f * Iv{p,c};
                    end;
                    B{r} = B{r} - f * B{p};
                end;
            end;
        end;
        do r = 1 to &k;
            bt{r} = B{r};
            do c = 1 to &k; V{r,c} = Iv{r,c}; end;
        end;
        output _beta;
        output _ainv;
    run;

    /*---- 5. cluster score vectors -------------------------------------*/
    data _sc(keep=_c &_SL);
        if _n_ = 1 then set _beta;
        set _fe1;
        array d{&k} &_DL;
        array bt{&k} beta1-beta&k;
        array s{&k} &_SL;
        xb = 0;
        do _j = 1 to &k; xb = xb + bt{_j} * d{_j}; end;
        e = y - xb;
        do _j = 1 to &k; s{_j} = w * d{_j} * e; end;
    run;
    proc means data=_sc noprint nway;
        class _c;
        var &_SL;
        output out=_cs(keep=_c &_SL) sum= ;
    run;

    /*---- 6. meat of the sandwich --------------------------------------*/
    data _meat(keep=m1-m&kk);
        set _cs end=_eof;
        array s{&k} &_SL;
        array M{&k,&k} m1-m&kk;
        retain m1-m&kk 0;
        do _r = 1 to &k;
            do _c2 = 1 to &k; M{_r,_c2} + s{_r} * s{_c2}; end;
        end;
        if _eof then output;
    run;

    /*---- 7. V = A M A, then rate ratios and 95% CI --------------------*/
    data &out;
        merge _ainv _meat _beta;
        length model $50 level $30;
        array V{&k,&k} v1-v&kk;
        array M{&k,&k} m1-m&kk;
        array bt{&k} beta1-beta&k;
        array T{&k,&k} _temporary_;
        do r = 1 to &k;
            do c = 1 to &k;
                t_ = 0;
                do q = 1 to &k; t_ = t_ + V{r,q} * M{q,c}; end;
                T{r,c} = t_;
            end;
        end;
        do r = 1 to &k;
            vr = 0;
            do q = 1 to &k; vr = vr + T{r,q} * V{q,r}; end;
            se      = sqrt(vr);
            model   = "&label";
            level   = scan("&levels", r);
            rr      = exp(bt{r});
            lcl     = exp(bt{r} - 1.96 * se);
            ucl     = exp(bt{r} + 1.96 * se);
            n_obs   = &_nobs;
            n_clust = &_ncl;
            output;
        end;
        keep model level rr lcl ucl se n_obs n_clust;
        label model='model' level='vs reference' rr='rate ratio'
              lcl='95% LCL' ucl='95% UCL' se='SE(log)'
              n_obs='rows' n_clust='clusters';
    run;

    proc datasets lib=work nolist;
        delete _fe0 _fe1 _gm _xtx _beta _ainv _sc _cs _meat;
    quit;

%mend fe_cr0;

%put NOTE: fe_cr0 macro loaded.;
* end of M_fe_cr0.sas ;
options validvarname=v7 nodate nonumber;
ods exclude all;

%let STABLE = 202510;
%let LEVELS = rush_Mon midday late pre8;


/* PANEL A: day and time cells, October 2025 to June 2026, practices with 1000 or more weekday calls (the table program XA) */
proc sql;
    create table _keepA as
    select practice from perm.cell_daytime
    where month >= "&STABLE." group by practice having sum(CBT001) >= 1000;
quit;
data XA;
    set perm.cell_daytime;
    where month >= "&STABLE.";
    if _n_ = 1 then do;
        declare hash k(dataset:'_keepA'); k.definekey('practice'); k.definedone();
    end;
    if k.check() ne 0 then delete;
run;

%fe_cr0(data=XA, num=CBT004,               den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fA, label=%str(A abandonment));
%fe_cr0(data=XA, num=CBT004+CBT005,        den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fB, label=%str(B real time non-connection));
%fe_cr0(data=XA, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fW, label=%str(W total non-connection));

proc sql;
    create table _dA as
    select cell length=20,
           sum(CBT001) / 1e6                       as calls_m,
           100 * sum(CBT004) / sum(CBT001)          as pA,
           100 * sum(CBT004 + CBT005) / sum(CBT001) as pB
    from XA group by cell;
    create table _nA as
    select count(distinct practice) as n_prac from XA;
quit;

data _rrA;
    merge fA(keep=level rr lcl ucl rename=(rr=rA lcl=lA ucl=uA))
          fB(keep=level rr lcl ucl rename=(rr=rB lcl=lB ucl=uB))
          fW(keep=level rr lcl ucl rename=(rr=rW lcl=lW ucl=uW));
    length cell $20; cell = level;
run;
proc sort data=_rrA; by cell; run;
proc sort data=_dA;  by cell; run;

data TA;
    length label $200 value $120 item $60;
    merge _dA(in=a) _rrA;
    by cell;
    if      cell = 'rush_TueFri' then do; item = 'Tuesday to Friday rush 08:00 to 10:00'; o = 1; end;
    else if cell = 'rush_Mon'    then do; item = 'Monday rush 08:00 to 10:00';            o = 2; end;
    else if cell = 'midday'      then do; item = 'Midday 10:00 to 16:00';                 o = 3; end;
    else if cell = 'late'        then do; item = 'Late afternoon 16:00 to 18:30';         o = 4; end;
    else if cell = 'pre8'        then do; item = 'pre-opening band 06:00 to 08:00';       o = 9; end;
    if o < 9 then do;
        ord = 10 * o;
        label = catx(' | ', 'Table 3 | Panel A', item, 'calls (millions)');             value = %fx(calls_m, 1); output;
        ord + 1; label = catx(' | ', 'Table 3 | Panel A', item, 'abandoned (%)');       value = %fx(pA, 1); output;
        ord + 1; label = catx(' | ', 'Table 3 | Panel A', item, 'real time non-connection (%)'); value = %fx(pB, 1); output;
        if cell = 'rush_TueFri' then do;
            ord + 1; label = catx(' | ', 'Table 3 | Panel A', item, 'rate ratio, all three definitions'); value = '1.00 (ref)'; output;
        end;
        else do;
            ord + 1; label = catx(' | ', 'Table 3 | Panel A', item, 'abandonment, RR (95% CI)');
                value = %fci(rA, lA, uA, 2); output;
            ord + 1; label = catx(' | ', 'Table 3 | Panel A', item, 'real time non-connection, RR (95% CI)');
                value = %fci(rB, lB, uB, 2); output;
            ord + 1; label = catx(' | ', 'Table 3 | Panel A', item, 'total non-connection, RR (95% CI)');
                value = %fci(rW, lW, uW, 2); output;
        end;
    end;
    else do;
        ord = 300; label = 'Table 3 footnote | pre-opening band 06:00 to 08:00, further calls (millions)';
        value = %fx(calls_m, 1); output;
    end;
    keep ord label value;
run;
data TAN;
    length label $200 value $120;
    set _nA;
    ord = 1; label = 'Table 3 | Panel A header | practices with 1000 or more weekday calls, October 2025 to June 2026';
    value = %fx(n_prac, 0);
    keep ord label value;
run;


/* PANEL B: type of day, calls 08:00 to 10:00, daily data, October 2024 to June 2026 (the table program XB) */
data XB;
    set perm.daily_rush;
    ymon = substr(Date, 1, 7);
run;
%fe_cr0(data=XB, num=CBT004,        den=CBT001, grp=daytype, ref=ordinary_Tuesday,
        levels=Wed_to_Fri ordinary_Monday postholiday_Tuesday,
        gid=catx('|', practice, ymon), cid=Date, out=bA, label=%str(A abandonment));
%fe_cr0(data=XB, num=CBT004+CBT005, den=CBT001, grp=daytype, ref=ordinary_Tuesday,
        levels=Wed_to_Fri ordinary_Monday postholiday_Tuesday,
        gid=catx('|', practice, ymon), cid=Date, out=bB, label=%str(B real time non-connection));

proc sql;
    create table _dB as
    select daytype length=24,
           count(distinct Date)                     as days,
           sum(CBT001) / 1e6                        as calls_m,
           100 * sum(CBT004) / sum(CBT001)          as pA,
           100 * sum(CBT004 + CBT005) / sum(CBT001) as pB
    from perm.daily_rush group by daytype;
    create table _nB as
    select count(distinct practice) as n_prac, count(distinct Date) as n_days from perm.daily_rush;
quit;
data _rrB;
    merge bA(keep=level rr lcl ucl rename=(rr=rA lcl=lA ucl=uA))
          bB(keep=level rr lcl ucl rename=(rr=rB lcl=lB ucl=uB));
    length daytype $24; daytype = level;
run;
proc sort data=_rrB; by daytype; run;
proc sort data=_dB;  by daytype; run;

data TB;
    length label $200 value $120 item $60;
    merge _dB(in=a) _rrB;
    by daytype;
    if      daytype = 'ordinary_Tuesday'    then do; item = 'Ordinary Tuesday';             o = 1; end;
    else if daytype = 'Wed_to_Fri'          then do; item = 'Wednesday to Friday';          o = 2; end;
    else if daytype = 'ordinary_Monday'     then do; item = 'Ordinary Monday';              o = 3; end;
    else if daytype = 'postholiday_Tuesday' then do; item = 'Tuesday after a bank holiday'; o = 4; end;
    ord = 100 + 10 * o;
    label = catx(' | ', 'Table 3 | Panel B', item, 'days');                            value = %fx(days, 0); output;
    ord + 1; label = catx(' | ', 'Table 3 | Panel B', item, 'calls (millions)');       value = %fx(calls_m, 1); output;
    ord + 1; label = catx(' | ', 'Table 3 | Panel B', item, 'abandoned (%)');          value = %fx(pA, 1); output;
    ord + 1; label = catx(' | ', 'Table 3 | Panel B', item, 'real time non-connection (%)'); value = %fx(pB, 1); output;
    if o = 1 then do;
        ord + 1; label = catx(' | ', 'Table 3 | Panel B', item, 'rate ratio'); value = '1.00 (ref)'; output;
    end;
    else do;
        ord + 1; label = catx(' | ', 'Table 3 | Panel B', item, 'abandonment, RR (95% CI)');
            value = %fci(rA, lA, uA, 2); output;
        ord + 1; label = catx(' | ', 'Table 3 | Panel B', item, 'real time non-connection, RR (95% CI)');
            value = %fci(rB, lB, uB, 2); output;
    end;
    keep ord label value;
run;
data TBN;
    length label $200 value $120;
    set _nB;
    ord = 101; label = 'Table 3 | Panel B header | practices'; value = %fx(n_prac, 0); output;
    ord = 102; label = 'Table 3 | Panel B header | calendar days'; value = %fx(n_days, 0); output;
    keep ord label value;
run;

data T3; set TAN TA TBN TB; run;
proc sort data=T3; by ord; run;

%out_start(T3_table3);
%out_add(T3);
%out_write;

* PART 3. Supplementary tables S1 to S5 ;

/* MS_wls.sas - weighted least squares with HC1 standard errors (%wls) and its interval helper (%wlsci).
   Copied without change from the table program (lines 128-244); the same macro is used by check program 24, 25, 25c, 26.  INCLUDE ONLY. */
/*----- weighted least squares with HC1 robust SE - Base SAS -----*/
/* %wls(data=, y=, x=, w=, out=, tag=)  -> out: tag var coef se t r2 n
   Intercept included automatically. k regressors, k <= 12.              */
%macro wls(data=, y=, x=, w=, out=, tag=);
    %local k p i;
    %let k = %sysfunc(countw(&x)); %let p = %eval(&k + 1);
    data _w1;
        set &data;
        where &y ne . and &w ne . and &w > 0
        %do i = 1 %to &k; and %scan(&x, &i) ne . %end; ;
        keep &y &x &w;
    run;
    /* pass 1: X'WX, X'Wy */
    data _xtx(keep=i j v) _xty(keep=i v) _n(keep=n ybar sw);
        set _w1 end=eof;
        array xv{&p} _temporary_;
        array A{&p, &p} _temporary_;
        array b{&p} _temporary_;
        if _n_ = 1 then do;                      /* temporary arrays start missing: zero them */
            do i = 1 to &p; b{i} = 0; do j = 1 to &p; A{i, j} = 0; end; end;
        end;
        xv{1} = 1;
        %do i = 1 %to &k; xv{%eval(&i + 1)} = %scan(&x, &i); %end;
        do i = 1 to &p;
            b{i} = b{i} + &w * xv{i} * &y;
            do j = 1 to &p; A{i, j} = A{i, j} + &w * xv{i} * xv{j}; end;
        end;
        n + 1; sw + &w; swy + &w * &y;
        if eof then do;
            ybar = swy / sw;
            do i = 1 to &p;
                v = b{i}; output _xty;
                do j = 1 to &p; v = A{i, j}; output _xtx; end;
            end;
            output _n;
        end;
    run;
    /* invert A by Gauss-Jordan, beta = Ainv b */
    data _inv(keep=i j v) _beta(keep=i beta);
        array A{&p, &p} _temporary_; array b{&p} _temporary_;
        array Inv{&p, &p} _temporary_;
        do until (e1); set _xtx end=e1; A{i, j} = v; end;
        do until (e2); set _xty end=e2; b{i} = v; end;
        do i = 1 to &p; do j = 1 to &p; Inv{i, j} = (i = j); end; end;
        do c = 1 to &p;
            piv = A{c, c};
            if abs(piv) < 1e-12 then do; put "ERROR: singular X'WX in wls &tag"; abort cancel; end;
            do j = 1 to &p; A{c, j} = A{c, j} / piv; Inv{c, j} = Inv{c, j} / piv; end;
            do r = 1 to &p; if r ne c then do;
                f = A{r, c};
                do j = 1 to &p; A{r, j} = A{r, j} - f * A{c, j}; Inv{r, j} = Inv{r, j} - f * Inv{c, j}; end;
            end; end;
        end;
        do i = 1 to &p;
            beta = 0; do j = 1 to &p; beta = beta + Inv{i, j} * b{j}; end; output _beta;
            do j = 1 to &p; v = Inv{i, j}; output _inv; end;
        end;
        stop;
    run;
    /* pass 2: residuals, HC1 meat, weighted R2 */
    data _meat(keep=i j v) _fit(keep=r2);
        array xv{&p} _temporary_; array bt{&p} _temporary_;
        array M{&p, &p} _temporary_;
        if _n_ = 1 then do;
            do until (e1); set _beta end=e1; bt{i} = beta; end;
            set _n;
            do i = 1 to &p; do j = 1 to &p; M{i, j} = 0; end; end;
        end;
        set _w1 end=eof;
        xv{1} = 1;
        %do i = 1 %to &k; xv{%eval(&i + 1)} = %scan(&x, &i); %end;
        yhat = 0; do i = 1 to &p; yhat = yhat + bt{i} * xv{i}; end;
        e = &y - yhat;
        rss + &w * e * e; tss + &w * (&y - ybar) ** 2;
        do i = 1 to &p; do j = 1 to &p; M{i, j} = M{i, j} + (&w * e) ** 2 * xv{i} * xv{j}; end; end;
        if eof then do;
            r2 = 1 - rss / tss; output _fit;
            do i = 1 to &p; do j = 1 to &p; v = M{i, j}; output _meat; end; end;
        end;
    run;
    data &out(keep=tag var coef se t r2 n);
        length tag $40 var $32;
        array Inv{&p, &p} _temporary_; array M{&p, &p} _temporary_; array Vc{&p, &p} _temporary_;   /* not 'V': clashes with variable v */
        array bt{&p} _temporary_;
        do until (e1); set _inv end=e1; Inv{i, j} = v; end;
        do until (e2); set _meat end=e2; M{i, j} = v; end;
        do until (e3); set _beta end=e3; bt{i} = beta; end;
        set _n; set _fit;
        /* V = Inv M Inv * n/(n-p) */
        do i = 1 to &p; do j = 1 to &p;
            s = 0;
            do a = 1 to &p; do c = 1 to &p; s = s + Inv{i, a} * M{a, c} * Inv{c, j}; end; end;
            Vc{i, j} = s * n / (n - &p);
        end; end;
        tag = "&tag";
        var = 'Intercept'; coef = bt{1}; se = sqrt(Vc{1, 1}); t = coef / se; output;
        %do i = 1 %to &k;
            var = "%scan(&x, &i)"; coef = bt{%eval(&i + 1)}; se = sqrt(Vc{%eval(&i + 1), %eval(&i + 1)}); t = coef / se; output;
        %end;
        stop;
    run;
%mend;


/*----- turn a %wls result into "coef (lo to hi)" -----*/
/* %wlsci(in=, out=, dp=)  adds lo, hi and a formatted cell to a %wls output.
   Uses the unrounded SE, so it does not match doubling the printed SE.      */
%macro wlsci(in=, out=, dp=3);
    data &out;
        set &in;
        length ci $30;
        lo = coef - 1.96 * se;
        hi = coef + 1.96 * se;
        ci = cats(put(coef, 8.&dp.), ' (', strip(put(lo, 8.&dp.)),
                  ' to ', strip(put(hi, 8.&dp.)), ')');
    run;
%mend;
/* MS_fe_cr0.sas - the log rate estimator %fe_cr0 (practice month fixed effect, call weighted, CR0 by cluster).
   Copied without change from 07_estimator.sas.  INCLUDE ONLY. */
/*-----
  [STEP 07] The estimator - INCLUDE ONLY, never run this on its own.
            08_table1 / 09_table2 / 11_appendix pull it in automatically.

  Defines one macro, %fe_cr0, which is the model used everywhere in the
  paper:

      log(numerator / denominator)
          = cell dummies + practice-month fixed effect + error
          weighted by the denominator (call volume)
          cluster-robust (CR0) standard errors

  Written in Base SAS only - no PROC REG, no PROC SURVEYREG, no IML - so it
  runs on any licence. The fixed effect is removed by weighted within-group
  demeaning, the coefficients come from solving the normal equations by
  Gauss-Jordan, and the variance is the usual sandwich

      V = (X'WX)^-1  [ sum_c s_c s_c' ]  (X'WX)^-1 ,
      s_c = sum over rows in cluster c of  w * x * residual

  which is exactly the CR0 estimator quoted in the manuscript.

  USAGE
      %fe_cr0(data   = perm.cell_daytime,
              num    = CBT004,                  * numerator expression;
              den    = CBT001,                  * denominator = weight;
              grp    = cell,                    * the categorical variable;
              ref    = rush_TueFri,             * reference level;
              levels = rush_Mon midday late pre8,
              gid    = catx('|', practice, month),   * fixed effect;
              cid    = practice,                * cluster;
              out    = t2_A,
              label  = A definition);

  OUT dataset columns: model level rr lcl ucl se n_obs n_clust
-----*/

%macro fe_cr0(data=, num=, den=, grp=, ref=, levels=, gid=, cid=,
              out=, label=);

    %local k kk i _DL _ML _SL _IN;
    %let k  = %sysfunc(countw(&levels));
    %let kk = %eval(&k * &k);
    %let _DL = ; %let _ML = ; %let _SL = ;
    %do i = 1 %to &k;
        %let _DL = &_DL d&i;
        %let _ML = &_ML md&i;
        %let _SL = &_SL s&i;
    %end;
    %let _IN = "&ref";
    %do i = 1 %to &k;
        %let _IN = &_IN, "%scan(&levels, &i)";
    %end;

    /*---- 1. y, weight, dummies; drop rows the log cannot take ----------*/
    data _fe0;
        set &data;
        length _g $60 _c $60;
        _num = &num;
        _den = &den;
        if _den > 0 and _num > 0;
        if &grp in (&_IN);
        y  = log(_num / _den);
        w  = _den;
        _g = &gid;
        _c = &cid;
        array d{&k} &_DL;
        do _j = 1 to &k; d{_j} = 0; end;
        %do i = 1 %to &k;
            if &grp = "%scan(&levels, &i)" then d&i = 1;
        %end;
        keep y w _g _c &_DL;
    run;

    proc sql noprint;
        select count(*), count(distinct _c) into :_nobs trimmed, :_ncl trimmed
        from _fe0;
    quit;

    /*---- 2. remove the practice-month fixed effect (weighted) ----------*/
    proc means data=_fe0 noprint nway;
        class _g;
        weight w;
        var y &_DL;
        output out=_gm(keep=_g my &_ML) mean(y &_DL) = my &_ML;
    run;
    proc sort data=_fe0; by _g; run;
    data _fe1;
        merge _fe0(in=a) _gm;
        by _g;
        array d{&k} &_DL;
        array m{&k} &_ML;
        y = y - my;
        do _j = 1 to &k; d{_j} = d{_j} - m{_j}; end;
        drop my &_ML _j;
    run;

    /*---- 3. accumulate X'WX and X'Wy ----------------------------------*/
    data _xtx(keep=a1-a&kk b1-b&k);
        set _fe1 end=_eof;
        array d{&k} &_DL;
        array A{&k,&k} a1-a&kk;
        array B{&k} b1-b&k;
        retain a1-a&kk b1-b&k 0;
        do _r = 1 to &k;
            B{_r} + w * d{_r} * y;
            do _c2 = 1 to &k;
                A{_r,_c2} + w * d{_r} * d{_c2};
            end;
        end;
        if _eof then output;
    run;

    /*---- 4. Gauss-Jordan: beta and (X'WX)^-1 --------------------------*/
    data _beta(keep=beta1-beta&k) _ainv(keep=v1-v&kk);
        set _xtx;
        array A{&k,&k} a1-a&kk;
        array B{&k} b1-b&k;
        array Iv{&k,&k} _temporary_;
        array V{&k,&k} v1-v&kk;
        array bt{&k} beta1-beta&k;
        do r = 1 to &k;
            do c = 1 to &k; Iv{r,c} = (r = c); end;
        end;
        do p = 1 to &k;
            piv = A{p,p};
            if abs(piv) < 1e-10 then do;
                put "ERROR: singular design matrix in fe_cr0 (&label)";
                abort cancel;
            end;
            do c = 1 to &k;
                A{p,c}  = A{p,c}  / piv;
                Iv{p,c} = Iv{p,c} / piv;
            end;
            B{p} = B{p} / piv;
            do r = 1 to &k;
                if r ne p then do;
                    f = A{r,p};
                    do c = 1 to &k;
                        A{r,c}  = A{r,c}  - f * A{p,c};
                        Iv{r,c} = Iv{r,c} - f * Iv{p,c};
                    end;
                    B{r} = B{r} - f * B{p};
                end;
            end;
        end;
        do r = 1 to &k;
            bt{r} = B{r};
            do c = 1 to &k; V{r,c} = Iv{r,c}; end;
        end;
        output _beta;
        output _ainv;
    run;

    /*---- 5. cluster score vectors -------------------------------------*/
    data _sc(keep=_c &_SL);
        if _n_ = 1 then set _beta;
        set _fe1;
        array d{&k} &_DL;
        array bt{&k} beta1-beta&k;
        array s{&k} &_SL;
        xb = 0;
        do _j = 1 to &k; xb = xb + bt{_j} * d{_j}; end;
        e = y - xb;
        do _j = 1 to &k; s{_j} = w * d{_j} * e; end;
    run;
    proc means data=_sc noprint nway;
        class _c;
        var &_SL;
        output out=_cs(keep=_c &_SL) sum= ;
    run;

    /*---- 6. meat of the sandwich --------------------------------------*/
    data _meat(keep=m1-m&kk);
        set _cs end=_eof;
        array s{&k} &_SL;
        array M{&k,&k} m1-m&kk;
        retain m1-m&kk 0;
        do _r = 1 to &k;
            do _c2 = 1 to &k; M{_r,_c2} + s{_r} * s{_c2}; end;
        end;
        if _eof then output;
    run;

    /*---- 7. V = A M A, then rate ratios and 95% CI --------------------*/
    data &out;
        merge _ainv _meat _beta;
        length model $50 level $30;
        array V{&k,&k} v1-v&kk;
        array M{&k,&k} m1-m&kk;
        array bt{&k} beta1-beta&k;
        array T{&k,&k} _temporary_;
        do r = 1 to &k;
            do c = 1 to &k;
                t_ = 0;
                do q = 1 to &k; t_ = t_ + V{r,q} * M{q,c}; end;
                T{r,c} = t_;
            end;
        end;
        do r = 1 to &k;
            vr = 0;
            do q = 1 to &k; vr = vr + T{r,q} * V{q,r}; end;
            se      = sqrt(vr);
            model   = "&label";
            level   = scan("&levels", r);
            rr      = exp(bt{r});
            lcl     = exp(bt{r} - 1.96 * se);
            ucl     = exp(bt{r} + 1.96 * se);
            n_obs   = &_nobs;
            n_clust = &_ncl;
            output;
        end;
        keep model level rr lcl ucl se n_obs n_clust;
        label model='model' level='vs reference' rr='rate ratio'
              lcl='95% LCL' ucl='95% UCL' se='SE(log)'
              n_obs='rows' n_clust='clusters';
    run;

    proc datasets lib=work nolist;
        delete _fe0 _fe1 _gm _xtx _beta _ainv _sc _cs _meat;
    quit;

%mend fe_cr0;

%put NOTE: fe_cr0 macro loaded.;
/* MS_ppml.sas - Poisson pseudo maximum likelihood with a group fixed effect (%ppml_fe).
   Copied without change from the table program (lines 247-520).  INCLUDE ONLY. */
/*-----
  %ppml_fe - Poisson pseudo maximum likelihood with a group fixed effect,
             cluster-robust (CR0) standard errors, Base SAS only.

  Model      E[num_i] = den_i * exp(alpha_g(i) + x_i'beta)
             x = dummies for &levels, reference = &ref
             alpha_g = a fixed effect for every &gid (practice month)

  The group effect has a closed form given beta, so it is concentrated out
  instead of estimated:

      exp(alpha_g) = sum_g(num) / sum_g(den * exp(x'beta))

  which makes every Newton step a k x k system however many groups there
  are. The concentrated Hessian subtracts the group term,

      H = sum_i mu_i xt_i xt_i' ,   xt_i = x_i - (sum_g mu x)/(sum_g mu)

  and the variance is the same CR0 sandwich %fe_cr0 uses,

      V = H^-1 [ sum_c s_c s_c' ] H^-1 ,   s_c = sum_c (num - mu) xt .

  Unlike the log rate model this keeps rows whose numerator is zero, which
  is why it is a check on the main estimator and not a repeat of it.

  OUT columns: model level rr lcl ucl se n_obs n_clust iter
-----*/
%macro ppml_fe(data=, num=, den=, grp=, ref=, levels=, gid=, cid=,
               out=, label=, maxit=40, tol=0.000000001);

    %local k kk i j _DL _MD _SD _IN;
    %let k  = %sysfunc(countw(&levels));
    %let kk = %eval(&k * &k);
    %let _DL = ; %let _MD = ; %let _SD = ;
    %do i = 1 %to &k;
        %let _DL = &_DL d&i; %let _MD = &_MD md&i; %let _SD = &_SD sd&i;
    %end;
    %let _IN = "&ref";
    %do i = 1 %to &k; %let _IN = &_IN, "%scan(&levels, &i)"; %end;

    %global _PPCONV _PPIT;
    %let _PPCONV = 0; %let _PPIT = 0;

    /*---- design ---------------------------------------------------------*/
    data _pp0;
        set &data;
        length _g $60 _c $60;
        _num = &num;
        _den = &den;
        if _den > 0 and _num ne . and _num >= 0;
        if &grp in (&_IN);
        _g = &gid;
        _c = &cid;
        array d{&k} &_DL;
        do _j = 1 to &k; d{_j} = 0; end;
        %do i = 1 %to &k;
            if &grp = "%scan(&levels, &i)" then d&i = 1;
        %end;
        keep _num _den _g _c &_DL;
    run;
    proc sort data=_pp0; by _g; run;
    proc sql noprint;
        select count(*), count(distinct _c) into :_nobs trimmed, :_ncl trimmed from _pp0;
    quit;

    data _pb;
        array bt{&k} beta1-beta&k;
        do _j = 1 to &k; bt{_j} = 0; end;
        keep beta1-beta&k;
    run;

    /*---- Newton iterations ---------------------------------------------*/
    %do i = 1 %to &maxit;
    %if &_PPCONV = 0 %then %do;

        data _pw;
            if _n_ = 1 then set _pb;
            set _pp0;
            array d{&k} &_DL;
            array bt{&k} beta1-beta&k;
            xb = 0;
            do _j = 1 to &k; xb = xb + bt{_j} * d{_j}; end;
            w = _den * exp(xb);
        run;
        proc means data=_pw noprint nway;
            class _g; var _num w;
            output out=_pg(keep=_g gnum gw) sum(_num w) = gnum gw;
        run;
        data _pm;
            merge _pw(in=a) _pg;
            by _g;
            if gw > 0 then mu = w * gnum / gw; else mu = 0;
            array d{&k} &_DL;
            array md{&k} &_MD;
            do _j = 1 to &k; md{_j} = mu * d{_j}; end;
        run;
        proc means data=_pm noprint nway;
            class _g; var mu &_MD;
            output out=_pgm(keep=_g smu &_SD) sum(mu &_MD) = smu &_SD;
        run;
        data _pmm;
            merge _pm(in=a) _pgm;
            by _g;
        run;

        data _pacc(keep=u1-u&k h1-h&kk);
            set _pmm end=_eof;
            array d{&k} &_DL;
            array sd{&k} &_SD;
            array dt{&k} _temporary_;
            array U{&k} u1-u&k;
            array H{&k,&k} h1-h&kk;
            retain u1-u&k h1-h&kk 0;
            if smu > 0 then do _j = 1 to &k; dt{_j} = d{_j} - sd{_j} / smu; end;
                       else do _j = 1 to &k; dt{_j} = d{_j}; end;
            e = _num - mu;
            do _r = 1 to &k;
                U{_r} + e * dt{_r};
                do _c2 = 1 to &k; H{_r,_c2} + mu * dt{_r} * dt{_c2}; end;
            end;
            if _eof then output;
        run;

        /* Newton step: solve H step = U, update beta */
        data _pbn(keep=beta1-beta&k);
            set _pacc;
            if _n_ = 1 then set _pb;
            array U{&k} u1-u&k;
            array H{&k,&k} h1-h&kk;
            array bt{&k} beta1-beta&k;
            do p = 1 to &k;
                piv = H{p,p};
                if abs(piv) < 1e-12 then do;
                    put "ERROR: singular Hessian in ppml_fe (&label)"; abort cancel;
                end;
                do c = 1 to &k; H{p,c} = H{p,c} / piv; end;
                U{p} = U{p} / piv;
                do r = 1 to &k; if r ne p then do;
                    f = H{r,p};
                    do c = 1 to &k; H{r,c} = H{r,c} - f * H{p,c}; end;
                    U{r} = U{r} - f * U{p};
                end; end;
            end;
            mx = 0;
            do _j = 1 to &k;
                bt{_j} = bt{_j} + U{_j};
                mx = max(mx, abs(U{_j}));
            end;
            call symputx('_PPCONV', (mx < &tol), 'G');
            call symputx('_PPIT', &i, 'G');
        run;
        proc datasets lib=work nolist; delete _pb; change _pbn = _pb; quit;
    %end;
    %end;

    /*---- final pass: mu, scores by cluster, sandwich --------------------*/
    data _pw;
        if _n_ = 1 then set _pb;
        set _pp0;
        array d{&k} &_DL;
        array bt{&k} beta1-beta&k;
        xb = 0;
        do _j = 1 to &k; xb = xb + bt{_j} * d{_j}; end;
        w = _den * exp(xb);
    run;
    proc means data=_pw noprint nway;
        class _g; var _num w;
        output out=_pg(keep=_g gnum gw) sum(_num w) = gnum gw;
    run;
    data _pm;
        merge _pw(in=a) _pg;
        by _g;
        if gw > 0 then mu = w * gnum / gw; else mu = 0;
        array d{&k} &_DL;
        array md{&k} &_MD;
        do _j = 1 to &k; md{_j} = mu * d{_j}; end;
    run;
    proc means data=_pm noprint nway;
        class _g; var mu &_MD;
        output out=_pgm(keep=_g smu &_SD) sum(mu &_MD) = smu &_SD;
    run;
    data _pmm;
        merge _pm(in=a) _pgm;
        by _g;
        array d{&k} &_DL;
        array sd{&k} &_SD;
        array s{&k} s1-s&k;
        if smu > 0 then do _j = 1 to &k; s{_j} = (_num - mu) * (d{_j} - sd{_j} / smu); end;
                   else do _j = 1 to &k; s{_j} = (_num - mu) * d{_j}; end;
        keep _c _g mu &_DL &_SD smu _num s1-s&k;
    run;

    data _pacc(keep=h1-h&kk);
        set _pmm end=_eof;
        array d{&k} &_DL;
        array sd{&k} &_SD;
        array dt{&k} _temporary_;
        array H{&k,&k} h1-h&kk;
        retain h1-h&kk 0;
        if smu > 0 then do _j = 1 to &k; dt{_j} = d{_j} - sd{_j} / smu; end;
                   else do _j = 1 to &k; dt{_j} = d{_j}; end;
        do _r = 1 to &k;
            do _c2 = 1 to &k; H{_r,_c2} + mu * dt{_r} * dt{_c2}; end;
        end;
        if _eof then output;
    run;

    proc means data=_pmm noprint nway;
        class _c; var s1-s&k;
        output out=_pcs(keep=_c s1-s&k) sum= ;
    run;
    data _pmeat(keep=m1-m&kk);
        set _pcs end=_eof;
        array s{&k} s1-s&k;
        array M{&k,&k} m1-m&kk;
        retain m1-m&kk 0;
        do _r = 1 to &k;
            do _c2 = 1 to &k; M{_r,_c2} + s{_r} * s{_c2}; end;
        end;
        if _eof then output;
    run;

    /* Hinv by Gauss-Jordan, then V = Hinv M Hinv */
    data _phinv(keep=v1-v&kk);
        set _pacc;
        array H{&k,&k} h1-h&kk;
        array Iv{&k,&k} _temporary_;
        array V{&k,&k} v1-v&kk;
        do r = 1 to &k; do c = 1 to &k; Iv{r,c} = (r = c); end; end;
        do p = 1 to &k;
            piv = H{p,p};
            do c = 1 to &k; H{p,c} = H{p,c} / piv; Iv{p,c} = Iv{p,c} / piv; end;
            do r = 1 to &k; if r ne p then do;
                f = H{r,p};
                do c = 1 to &k; H{r,c} = H{r,c} - f * H{p,c}; Iv{r,c} = Iv{r,c} - f * Iv{p,c}; end;
            end; end;
        end;
        do r = 1 to &k; do c = 1 to &k; V{r,c} = Iv{r,c}; end; end;
    run;

    data &out;
        merge _phinv _pmeat _pb;
        length model $50 level $30;
        array V{&k,&k} v1-v&kk;
        array M{&k,&k} m1-m&kk;
        array bt{&k} beta1-beta&k;
        array T{&k,&k} _temporary_;
        do r = 1 to &k; do c = 1 to &k;
            t_ = 0; do q = 1 to &k; t_ = t_ + V{r,q} * M{q,c}; end; T{r,c} = t_;
        end; end;
        do r = 1 to &k;
            vr = 0; do q = 1 to &k; vr = vr + T{r,q} * V{q,r}; end;
            se      = sqrt(vr);
            model   = "&label";
            level   = scan("&levels", r);
            rr      = exp(bt{r});
            lcl     = exp(bt{r} - 1.96 * se);
            ucl     = exp(bt{r} + 1.96 * se);
            n_obs   = &_nobs;
            n_clust = &_ncl;
            iter    = &_PPIT;
            output;
        end;
        keep model level rr lcl ucl se n_obs n_clust iter;
    run;

    proc datasets lib=work nolist;
        delete _pp0 _pw _pg _pm _pgm _pmm _pacc _pcs _pmeat _phinv _pb;
    quit;
%mend ppml_fe;

%put NOTE: ppml_fe macro loaded.;

* Table S1 (TS1_tableS1) ;
%fresh;

/* TS1_tableS1.sas - Table S1. The main results under five definitions of a failed call.
   Every number in table S1 and its footnotes, written to output\TS1_tableS1.txt.
   Derived from:
     the table program: TABLE S1 PANEL 1, PANEL 2, PANEL 3 (a) to (c), PANEL 3 footnote numbers,
       FOOTNOTE NUMBERS (national levels) - via MS_s1cells.sas for panels 1 and 2;
     check program 25 part 2 (abandoned plus menu ended calls) - via MS_s1cells.sas;
     analysis program 09 parts E and F (= check program 23 parts E and F): zero cells, May 2026;
     analysis program 10 parts 1 and 4: pre-opening menu ended share, menu ended slope;
     check program 33 parts 11 and 13: recorded outcomes v inbound calls, callback share.
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only).  ASCII only.  Run: RUN_TS1_tableS1.bat */

%let PROG = TS1_tableS1;
%let EXH  = Table S1;
* from MS_setup.sas ;
/* MS_setup.sas - common set-up for the supplementary table programs TS1 to TS5.  INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder), PROG (its own name) and EXH (the exhibit label) first.
   Does:  options; ODS output excluded (programs compute quietly); 00_paths.sas (one folder up);
          the estimator macros (MS_wls.sas, MS_fe_cr0.sas, MS_ppml.sas); number formatting functions;
          the results table RES, the macro %add that puts one number into it, and %ms_write that writes
          RES to output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;   /* nothing is printed; results go to RES and output\PROG.txt */

/* the output file of this table, in the folder OUT (PART 0) */
%macro _ms_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_ms_dirs;

* input folders and libraries: set once in PART 1 ;
* MS_wls macros: defined in PART 3 ;
* MS_fe_cr0 macros: defined in PART 3 ;
* MS_ppml macros: defined in PART 3 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.msfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values (falsification rows of table S2) */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if input(s, best32.) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    function cis(e, l, h, d) $ 120;
        length s $120;
        s = strip(sg(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 72 713) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
run;
options cmplib=work.msfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(12), part char(80), row char(160), col char(80), value char(120));
quit;

/* %add(order, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro add(o, part, row, col, val, ds=_one, wh=1);
    %local _n;
    data _addrow;
        set &ds;
        where &wh;
        length _x_exh $12 _x_part $80 _x_row $160 _x_col $80 _x_val $120;
        _x_ord = &o; _x_exh = "&EXH"; _x_part = "&part"; _x_row = "&row"; _x_col = "&col";
        _x_val = &val;
        keep _x_ord _x_exh _x_part _x_row _x_col _x_val;
    run;
    proc sql noprint; select count(*) into :_n trimmed from _addrow; quit;
    %if &_n ne 1 %then %do; %put ERROR: add &o selected &_n rows instead of one.; %abort cancel; %end;
    proc append base=RES force
        data=_addrow(rename=(_x_ord=ord _x_exh=exhibit _x_part=part _x_row=row _x_col=col _x_val=value));
    run;
%mend;

%macro ms_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MS_setup.sas ;

%let T1MONTH = 202606;
%let NBOOT   = 2000;

/* ---- panels 1 and 2 (and the abandoned plus menu ended models of the footnote) ---- */
* from MS_s1cells.sas ;
/* MS_s1cells.sas - INCLUDE ONLY.  ASCII only.
   Time cell rate ratios behind table S1 panels 1 and 2 (and the rows of table S3 that summarise them).
   From the table program: common dataset XA; TABLE 3 and TABLE S1 PANEL 1 (%fe_cr0, five definitions);
   TABLE S1 PANEL 2 (%ppml_fe, five definitions).  From check program 25 part 2: abandoned plus menu ended
   calls without callback requests, log rate model and Poisson.
   Creates: XA; fA fB fAs fBs fW (log rate); pA pB pAs pBs pW (Poisson); fAM pAM (abandoned plus menu ended).
   Each has one row per level (rush_Mon midday late pre8) with rr lcl ucl n_clust. */

%let STABLE = 202510;
%let LEVELS = rush_Mon midday late pre8;

/* XA : day and time cells in the stable window, practices with 1000+ calls */
proc sql;
    create table _keepA as
    select practice from perm.cell_daytime
    where month >= "&STABLE." group by practice having sum(CBT001) >= 1000;
quit;
data XA;
    set perm.cell_daytime;
    where month >= "&STABLE.";
    if _n_ = 1 then do;
        declare hash k(dataset:'_keepA'); k.definekey('practice'); k.definedone();
    end;
    if k.check() ne 0 then delete;
    q = CBT001 - CBT002;
run;

%fe_cr0(data=XA, num=CBT004,               den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fA,  label=%str(A abandonment));
%fe_cr0(data=XA, num=CBT004+CBT005,        den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fB,  label=%str(B real time non-connection));
%fe_cr0(data=XA, num=CBT004,               den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fAs, label=%str(A* queue restricted abandonment));
%fe_cr0(data=XA, num=CBT004+CBT005,        den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fBs, label=%str(B* queue restricted non-connection));
%fe_cr0(data=XA, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fW,  label=%str(W total non-connection));

%ppml_fe(data=XA, num=CBT004,               den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pA,  label=%str(A abandonment));
%ppml_fe(data=XA, num=CBT004+CBT005,        den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pB,  label=%str(B real time non-connection));
%ppml_fe(data=XA, num=CBT004,               den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pAs, label=%str(A* queue restricted abandonment));
%ppml_fe(data=XA, num=CBT004+CBT005,        den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pBs, label=%str(B* queue restricted non-connection));
%ppml_fe(data=XA, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pW,  label=%str(W total non-connection));

/* check program 25 part 2: abandoned + menu ended (callback requests not counted) */
%fe_cr0(data=XA, num=CBT002+CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fAM, label=%str(A+M log rate WLS));
%ppml_fe(data=XA, num=CBT002+CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pAM, label=%str(A+M Poisson));

/* all models stacked, one row per definition and level: defn in A B As Bs W AM, est in LR PO */
data S1RR;
    length defn $4 est $2;
    set fA(in=a1) fB(in=a2) fAs(in=a3) fBs(in=a4) fW(in=a5) fAM(in=a6)
        pA(in=b1) pB(in=b2) pAs(in=b3) pBs(in=b4) pW(in=b5) pAM(in=b6);
    if a1 or b1 then defn = 'A';  else if a2 or b2 then defn = 'B';  else if a3 or b3 then defn = 'As';
    else if a4 or b4 then defn = 'Bs'; else if a5 or b5 then defn = 'W'; else defn = 'AM';
    est = ifc(a1 or a2 or a3 or a4 or a5 or a6, 'LR', 'PO');
    keep defn est level rr lcl ucl n_clust;
run;
* end of MS_s1cells.sas ;


/* ---- panel 3 (the table program common dataset XP, TABLE S1 PANEL 3) ---- */
proc sql;
    create table _prate as
    select a.practice as practice_code,
           sum(a.CBT001) as inb, sum(a.CBT002) as menu,
           sum(a.CBT004) as ab,  sum(a.CBT005) as cb
    from XA a group by a.practice;
quit;
proc sql;
    create table _pdec as
    select practice_code, max(pw_imd_decile_1poorest) as decile
    from perm.practice_month where month = "&T1MONTH." group by practice_code;
quit;
proc sql;
    create table XP as
    select a.practice_code, b.decile,
           100 * a.ab / a.inb                       as rA,
           100 * (a.ab + a.cb) / a.inb              as rB,
           100 * a.ab / (a.inb - a.menu)            as rAs,
           100 * (a.ab + a.cb) / (a.inb - a.menu)   as rBs,
           100 * (a.ab + a.cb + a.menu) / a.inb     as rW,
           a.inb
    from _prate a left join _pdec b on a.practice_code = b.practice_code
    where a.inb > 0 and a.inb > a.menu;
quit;

/* (a) rank correlation with abandonment (and, for B*, with B) */
proc rank data=XP out=_xpr;
    var rA rB rAs rBs rW;
    ranks kA kB kAs kBs kW;
run;
%macro _rho(v1, v2, out);
    proc sql;
        create table &out as
        select (mean(&v1 * &v2) - mean(&v1) * mean(&v2)) /
               (std(&v1) * std(&v2)) * (count(*) / (count(*) - 1)) as rho
        from _xpr;
    quit;
%mend;
%_rho(kA, kB,  _rh1);  %_rho(kA, kAs, _rh2);
%_rho(kA, kBs, _rh3);  %_rho(kB, kBs, _rh4);  %_rho(kA, kW, _rh5);

/* (b) agreement on the worst decile */
proc rank data=XP out=_xpd groups=10 descending;
    var rA rB rAs rBs rW;
    ranks wA wB wAs wBs wW;
run;
data _xpd; set _xpd; worstA = (wA = 0); run;
proc sql;
    create table s1p3_agree as
    select 'B' as defn length=4, 100 * mean(wB  = 0) as agree from _xpd where worstA = 1
    union all
    select 'As', 100 * mean(wAs = 0) from _xpd where worstA = 1
    union all
    select 'BsB', 100 * mean(wBs = 0) from _xpd where wB = 0
    union all
    select 'W',  100 * mean(wW = 0) from _xpd where worstA = 1;
quit;

/* (c) most v least deprived decile, ratio of unweighted practice means, bootstrap within deciles (fig S8 rule) */
%macro depratio;
    data _bsrc;
        set perm.practice_summary;
        where inbound_stablewin >= 1000 and mon_rush_inbound > 0
          and pw_imd_decile_1poorest in (1, 10)
          and inbound_stablewin > menu_stablewin;
        rA  = 100 * abandoned_stablewin / inbound_stablewin;
        rB  = 100 * (abandoned_stablewin + callback_req_stablewin) / inbound_stablewin;
        rAs = 100 * abandoned_stablewin / (inbound_stablewin - menu_stablewin);
        rBs = 100 * (abandoned_stablewin + callback_req_stablewin) / (inbound_stablewin - menu_stablewin);
        rW  = 100 * (abandoned_stablewin + callback_req_stablewin + menu_stablewin) / inbound_stablewin;
        decile = pw_imd_decile_1poorest;
        keep decile rA rB rAs rBs rW;
    run;
    proc sql;
        create table _pt as
        select 'A'  as defn length=4,
               (select mean(rA)  from _bsrc where decile = 1) /
               (select mean(rA)  from _bsrc where decile = 10) as ratio from _bsrc(obs=1)
        union all select 'B',
               (select mean(rB)  from _bsrc where decile = 1) /
               (select mean(rB)  from _bsrc where decile = 10) from _bsrc(obs=1)
        union all select 'As',
               (select mean(rAs) from _bsrc where decile = 1) /
               (select mean(rAs) from _bsrc where decile = 10) from _bsrc(obs=1)
        union all select 'Bs',
               (select mean(rBs) from _bsrc where decile = 1) /
               (select mean(rBs) from _bsrc where decile = 10) from _bsrc(obs=1)
        union all select 'W',
               (select mean(rW)  from _bsrc where decile = 1) /
               (select mean(rW)  from _bsrc where decile = 10) from _bsrc(obs=1);
    quit;
    data _boot(keep=rep bA bB bAs bBs bW);
        array a1{3000} _temporary_; array b1{3000} _temporary_; array c1{3000} _temporary_;
        array d1{3000} _temporary_; array w1{3000} _temporary_;
        array a0{3000} _temporary_; array b0{3000} _temporary_; array c0{3000} _temporary_;
        array d0{3000} _temporary_; array w0{3000} _temporary_;
        retain n1 n0 0;
        call streaminit(20260901);
        do until (eof);
            set _bsrc end=eof;
            if decile = 1 then do; n1 + 1; a1{n1}=rA; b1{n1}=rB; c1{n1}=rAs; d1{n1}=rBs; w1{n1}=rW; end;
            else do;               n0 + 1; a0{n0}=rA; b0{n0}=rB; c0{n0}=rAs; d0{n0}=rBs; w0{n0}=rW; end;
        end;
        do rep = 1 to &NBOOT;
            sa1=0; sb1=0; sc1=0; sd1=0; sw1=0;
            do i = 1 to n1;
                j = rand('integer', 1, n1);
                sa1 + a1{j}; sb1 + b1{j}; sc1 + c1{j}; sd1 + d1{j}; sw1 + w1{j};
            end;
            sa0=0; sb0=0; sc0=0; sd0=0; sw0=0;
            do i = 1 to n0;
                j = rand('integer', 1, n0);
                sa0 + a0{j}; sb0 + b0{j}; sc0 + c0{j}; sd0 + d0{j}; sw0 + w0{j};
            end;
            bA  = (sa1/n1)/(sa0/n0);  bB  = (sb1/n1)/(sb0/n0);
            bAs = (sc1/n1)/(sc0/n0);  bBs = (sd1/n1)/(sd0/n0);
            bW  = (sw1/n1)/(sw0/n0);
            output;
        end;
        stop;
    run;
    proc univariate data=_boot noprint;
        var bA bB bAs bBs bW;
        output out=_bci pctlpts=2.5 97.5
               pctlpre=cA_ cB_ cAs_ cBs_ cW_ pctlname=lo hi;
    run;
%mend;
%depratio;
data s1p3_dep;
    length defn $4;
    if _n_ = 1 then set _bci;
    set _pt;
    if      defn = 'A'  then do; lo = cA_lo;  hi = cA_hi;  end;
    else if defn = 'B'  then do; lo = cB_lo;  hi = cB_hi;  end;
    else if defn = 'As' then do; lo = cAs_lo; hi = cAs_hi; end;
    else if defn = 'Bs' then do; lo = cBs_lo; hi = cBs_hi; end;
    else                     do; lo = cW_lo;  hi = cW_hi;  end;
    keep defn ratio lo hi;
run;

/* panel 3 footnote: sample, the best decile, and the illustrative practice */
proc sql;
    create table _s1n as select count(*) as n from XP;
quit;
proc rank data=XP out=_xpb groups=10;      /* ascending: group 0 = lowest rate */
    var rA rB rAs rBs rW;
    ranks bA bB bAs bBs bW;
run;
proc sql;
    create table s1p3_best as
    select 100 * (1 - mean(bB = 0)) as outside_best from _xpb where bA = 0;
    create table s1p3_ex as
    select rA as ex_abandoned, rB as ex_realtime
    from _xpb where bA = 0 having rB = max(rB);
quit;


/* ---- footnote numbers ---- */
/* national levels over the 21 months, all hours (the table program FOOTNOTE NUMBERS); callback share (check program 33 part 13) */
proc sql;
    create table _lev as
    select 100 * sum(cbt004_missed) / sum(cbt001_inbound)                                          as lA,
           100 * sum(cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound)                    as lB,
           100 * sum(cbt004_missed) / sum(cbt001_inbound - cbt002_ivr_ended)                       as lAs,
           100 * sum(cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound - cbt002_ivr_ended) as lBs,
           100 * sum(cbt002_ivr_ended + cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound) as lW,
           100 * sum(cbt002_ivr_ended) / sum(cbt001_inbound)                                       as lmenu,
           100 * sum(cbt005_cb_requested) / sum(cbt001_inbound)                                    as lcb,
           sum(cbt004_missed) / sum(cbt001_inbound - cbt002_ivr_ended)                             as lAs_points
    from perm.practice_month where cbt_observed = 1;
    create table _levh as
    select 100 * sum(CBT002) / sum(CBT001) as lmenu_h from perm.cell_daytime where cell ne 'pre8';
quit;
/* May 2026 (analysis program 09 part F) */
proc sql;
    create table _may as
    select 'all' as basis length=4,
           100 * (1 - sum(cbt002_ivr_ended + cbt004_missed) / sum(cbt001_inbound)) as pct,
           100 * sum(cbt002_ivr_ended) / sum(cbt001_inbound) as menu_pct
    from perm.practice_month where month = '202605' and cbt_observed = 1
    union all
    select 'open',
           100 * (1 - sum(CBT002 + CBT004) / sum(CBT001)),
           100 * sum(CBT002) / sum(CBT001)
    from perm.cell_daytime where month = '202605' and cell ne 'pre8';
quit;
/* the four recorded outcomes v inbound calls, 21 months (check program 33 part 11) */
proc sql;
    create table _dev as
    select 100 - 100 * (sum(cbt002_ivr_ended) + sum(cbt003_answered) + sum(cbt004_missed) + sum(cbt005_cb_requested))
               / sum(cbt001_inbound) as shortfall
    from perm.practice_month where cbt_observed = 1;
quit;
/* share of pre-opening calls that end in the menu, October 2025 to June 2026 (analysis program 10 part 1) */
proc sql;
    create table _pre as
    select 100 * sum(CBT002) / sum(CBT001) as menu_pre8
    from perm.cell_daytime where month >= '202510' and cell = 'pre8';
quit;
/* abandonment on menu ended share, separate practice and month fixed effects, call weighted, SE clustered by
   practice (analysis program 10 part 4) */
data _mw;
    set perm.practice_month;
    where cbt_observed = 1 and cbt001_inbound > 0;
    y = 100*cbt004_missed/cbt001_inbound;
    x = 100*cbt002_ivr_ended/cbt001_inbound;
    w = cbt001_inbound;
    keep practice_code month y x w;
run;
%macro _demean(iters=40);
    %do _i = 1 %to &iters;
        proc means data=_mw noprint nway;
            class practice_code; var y x; weight w;
            output out=_gp(keep=practice_code my mx) mean=my mx;
        run;
        proc sort data=_mw; by practice_code; run;
        data _mw; merge _mw _gp; by practice_code; y = y - my; x = x - mx; drop my mx; run;
        proc means data=_mw noprint nway;
            class month; var y x; weight w;
            output out=_gm(keep=month my mx) mean=my mx;
        run;
        proc sort data=_mw; by month; run;
        data _mw; merge _mw _gm; by month; y = y - my; x = x - mx; drop my mx; run;
    %end;
%mend;
%_demean;
proc sql noprint;
    select sum(w*x*y)/sum(w*x*x), sum(w*x*x)
      into :b_menu, :xwx
      from _mw;
quit;
data _res; set _mw; s = w*x*(y - (&b_menu)*x); run;
proc sort data=_res; by practice_code; run;
proc means data=_res noprint nway;
    class practice_code; var s; output out=_cl(keep=sc) sum=sc;
run;
proc sql noprint; select sum(sc*sc) into :meat from _cl; quit;
data _slope;
    slope = &b_menu;
    se    = sqrt(&meat)/(&xwx);
    lcl   = slope - 1.96*se;
    ucl   = slope + 1.96*se;
run;
/* cells with a zero numerator, which the log rate model drops (analysis program 09 part E) */
proc sql;
    create table _zero as
    select cell, 100 * mean(CBT004 = 0) as zero_aband
    from perm.cell_daytime
    where month >= '202510' and CBT001 > 0
    group by cell;
    create table _zero2 as
    select min(zero_aband) as zlo, max(zero_aband) as zhi
    from _zero where cell in ('rush_TueFri', 'midday', 'late');
quit;


/* ---- results, in the order of the table ---- */
%macro p12(panel, o, est);
    %local c d lab lev df cl;
    %do c = 1 %to 4;
        %let lev = %scan(rush_Mon midday late pre8, &c);
        %let lab = %scan(Monday rush 08:00 to 10:00|Midday 10:00 to 16:00|Late afternoon 16:00 to 18:30|Pre-opening 06:00 to 08:00, &c, |);
        %do d = 1 %to 5;
            %let df = %scan(A B As Bs W, &d);
            %let cl = %scan(Abandonment|Real time non-connection|Queue restricted abandonment|Queue restricted non-connection|Total non-connection, &d, |);
            %add(%eval(&o + 10 * &c + &d), &panel, &lab, &cl, ci(rr, lcl, ucl, 2), ds=S1RR,
                 wh=%str(est="&est" and defn="&df" and level="&lev"));
        %end;
    %end;
%mend;
%p12(Panel 1, 1000, LR);
%p12(Panel 2, 2000, PO);

%add(3011, Panel 3, Real time non-connection,        Rank correlation with abandonment, fn(rho, 2), ds=_rh1);
%add(3012, Panel 3, Real time non-connection,        Agreement on worst decile,         pc(agree, 1), ds=s1p3_agree, wh=%str(defn='B'));
%add(3013, Panel 3, Real time non-connection,        Most v least deprived RR,          ci(ratio, lo, hi, 2), ds=s1p3_dep, wh=%str(defn='B'));
%add(3010, Panel 3, Abandonment (published),         Most v least deprived RR,          ci(ratio, lo, hi, 2), ds=s1p3_dep, wh=%str(defn='A'));
%add(3021, Panel 3, Queue restricted abandonment,    Rank correlation with abandonment, fn(rho, 2), ds=_rh2);
%add(3022, Panel 3, Queue restricted abandonment,    Agreement on worst decile,         pc(agree, 1), ds=s1p3_agree, wh=%str(defn='As'));
%add(3023, Panel 3, Queue restricted abandonment,    Most v least deprived RR,          ci(ratio, lo, hi, 2), ds=s1p3_dep, wh=%str(defn='As'));
%add(3031, Panel 3, Queue restricted non-connection, Rank correlation (v real time non-connection), fn(rho, 2), ds=_rh4);
%add(3032, Panel 3, Queue restricted non-connection, Agreement on worst decile (v real time non-connection), pc(agree, 1), ds=s1p3_agree, wh=%str(defn='BsB'));
%add(3033, Panel 3, Queue restricted non-connection, Most v least deprived RR,          ci(ratio, lo, hi, 2), ds=s1p3_dep, wh=%str(defn='Bs'));
%add(3041, Panel 3, Total non-connection,            Rank correlation with abandonment, fn(rho, 2), ds=_rh5);
%add(3042, Panel 3, Total non-connection,            Agreement on worst decile,         pc(agree, 1), ds=s1p3_agree, wh=%str(defn='W'));
%add(3043, Panel 3, Total non-connection,            Most v least deprived RR,          ci(ratio, lo, hi, 2), ds=s1p3_dep, wh=%str(defn='W'));

%add(4001, Footnote 1, National level, Abandonment,                     pc(lA, 1),  ds=_lev);
%add(4002, Footnote 1, National level, Real time non-connection,        pc(lB, 1),  ds=_lev);
%add(4003, Footnote 1, National level, Queue restricted abandonment,    pc(lAs, 1), ds=_lev);
%add(4004, Footnote 1, National level, Queue restricted non-connection, pc(lBs, 1), ds=_lev);
%add(4005, Footnote 1, National level, Total non-connection,            pc(lW, 1),  ds=_lev);
%add(4006, Footnote 1, Callback requests, % of inbound calls,           pc(lcb, 1), ds=_lev);
%add(4007, Footnote 1, Menu ended calls, % of all calls,                pc(lmenu, 1), ds=_lev);
%add(4008, Footnote 1, Menu ended calls, % of opening hours calls,      pc(lmenu_h, 1), ds=_levh);
%add(4009, Footnote 1, May 2026 menu ended calls, % of all calls,                         pc(menu_pct, 1), ds=_may, wh=%str(basis='all'));
%add(4010, Footnote 1, May 2026 menu ended calls, % of opening hours calls,               pc(menu_pct, 1), ds=_may, wh=%str(basis='open'));
%add(4011, Footnote 1, May 2026 calls neither abandoned nor menu ended, % of all calls,   pc(pct, 1), ds=_may, wh=%str(basis='all'));
%add(4012, Footnote 1, May 2026 calls neither abandoned nor menu ended, % of opening hours calls, pc(pct, 1), ds=_may, wh=%str(basis='open'));
%add(4013, Footnote 1, Four recorded outcomes below inbound calls, percentage points,      fn(shortfall, 1), ds=_dev);

%add(4101, Footnote 2, Practices in panels 1 and 2, , fi(n_clust), ds=fA, wh=%str(level='rush_Mon'));
%add(4102, Footnote 2, Pre-opening rate ratio, published definition,       fn(rr, 2), ds=fA,  wh=%str(level='pre8'));
%add(4103, Footnote 2, Pre-opening rate ratio, queue restricted abandonment, fn(rr, 2), ds=fAs, wh=%str(level='pre8'));
%add(4104, Footnote 2, Pre-opening calls that end in the menu, , pc(menu_pre8, 0), ds=_pre);
%add(4105, Footnote 2, Measured abandonment lower per percentage point of menu ended share, points (95% CI), ci(-slope, -ucl, -lcl, 2), ds=_slope);
%add(4106, Footnote 2, Points the denominator alone would produce, , fn(lAs_points, 3), ds=_lev);
%add(4107, Footnote 2, National queue restricted level, , pc(lAs, 1), ds=_lev);
%add(4111, Footnote 2, Abandoned plus menu ended, Monday rush,    ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='AM' and level='rush_Mon'));
%add(4112, Footnote 2, Abandoned plus menu ended, Midday,         ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='AM' and level='midday'));
%add(4113, Footnote 2, Abandoned plus menu ended, Late afternoon, ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='AM' and level='late'));
%add(4114, Footnote 2, Abandoned plus menu ended (Poisson), Monday rush,    fn(rr, 2),           ds=S1RR, wh=%str(est='PO' and defn='AM' and level='rush_Mon'));
%add(4115, Footnote 2, Abandoned plus menu ended (Poisson), Midday,         ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='PO' and defn='AM' and level='midday'));
%add(4116, Footnote 2, Abandoned plus menu ended (Poisson), Late afternoon, ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='PO' and defn='AM' and level='late'));
%add(4121, Footnote 2, Cells with no abandoned calls, Monday rush cells,         pc(zero_aband, 2), ds=_zero, wh=%str(cell='rush_Mon'));
%add(4122, Footnote 2, Cells with no abandoned calls, other interpreted cells,   strip(pc(zlo, 2)) || ' to ' || strip(pc(zhi, 2)), ds=_zero2);
%add(4123, Footnote 2, Cells with no abandoned calls, pre-opening cells,         pc(zero_aband, 1), ds=_zero, wh=%str(cell='pre8'));

%add(4201, Footnote 3, Practices in panel 3, , fi(n), ds=_s1n);
%add(4202, Footnote 3, Best decile on abandonment moved out of the best decile on real time non-connection, , pc(outside_best, 1), ds=s1p3_best);
%add(4203, Footnote 3, Practice among the officially best, % abandoned,                 pc(ex_abandoned, 1), ds=s1p3_ex);
%add(4204, Footnote 3, Practice among the officially best, % not connected in real time, pc(ex_realtime, 1), ds=s1p3_ex);

%ms_write;

* Table S2 (TS2_tableS2) ;
%fresh;

/* TS2_tableS2.sas - Table S2. Change in patient reported ease of phone contact per percentage point of calls in each
   category, and adjusted comparisons of the definitions in table 2, GP Patient Survey 2025 and 2026.
   Every number in table S2 and its footnote, written to output\TS2_tableS2.txt.
   Derived from (run unless stated):
     the table program TABLE 2 PANEL 1 and PANEL 2 (rows across practices, opening hours, within practices,
       falsification test), FOOTNOTE NUMBERS (year to year correlation), VIF_CHECK (collinearity) - MS_link.sas;
     check program 26 part 9-2 (adjusted row) - MS_c25.sas;
     check program 25c 7-4 (rows with waiting time data) - MS_c25.sas;
     check program 24 parts 3, 4 and 5 (falsification test with 2025 levels, adjustment for 2024 ease and
       for the 2024 to 2025 change, covariate adjusted R2, the old W formula) - MS_c24.sas;
     check program 25 parts 3 and 4 (extended covariates; networks resampled) - MS_c25.sas;
     analysis program 09 part D (= check program 23 part D): Wald tests.
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only), the durations files and the GPAD files (read only).
   ASCII only.  Run: RUN_TS2_tableS2.bat */

%let PROG = TS2_tableS2;
%let EXH  = Table S2;
* from MS_setup.sas ;
/* MS_setup.sas - common set-up for the supplementary table programs TS1 to TS5.  INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder), PROG (its own name) and EXH (the exhibit label) first.
   Does:  options; ODS output excluded (programs compute quietly); 00_paths.sas (one folder up);
          the estimator macros (MS_wls.sas, MS_fe_cr0.sas, MS_ppml.sas); number formatting functions;
          the results table RES, the macro %add that puts one number into it, and %ms_write that writes
          RES to output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;   /* nothing is printed; results go to RES and output\PROG.txt */

/* the output file of this table, in the folder OUT (PART 0) */
%macro _ms_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_ms_dirs;

* input folders and libraries: set once in PART 1 ;
* MS_wls macros: defined in PART 3 ;
* MS_fe_cr0 macros: defined in PART 3 ;
* MS_ppml macros: defined in PART 3 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.msfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values (falsification rows of table S2) */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if input(s, best32.) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    function cis(e, l, h, d) $ 120;
        length s $120;
        s = strip(sg(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 72 713) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
run;
options cmplib=work.msfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(12), part char(80), row char(160), col char(80), value char(120));
quit;

/* %add(order, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro add(o, part, row, col, val, ds=_one, wh=1);
    %local _n;
    data _addrow;
        set &ds;
        where &wh;
        length _x_exh $12 _x_part $80 _x_row $160 _x_col $80 _x_val $120;
        _x_ord = &o; _x_exh = "&EXH"; _x_part = "&part"; _x_row = "&row"; _x_col = "&col";
        _x_val = &val;
        keep _x_ord _x_exh _x_part _x_row _x_col _x_val;
    run;
    proc sql noprint; select count(*) into :_n trimmed from _addrow; quit;
    %if &_n ne 1 %then %do; %put ERROR: add &o selected &_n rows instead of one.; %abort cancel; %end;
    proc append base=RES force
        data=_addrow(rename=(_x_ord=ord _x_exh=exhibit _x_part=part _x_row=row _x_col=col _x_val=value));
    run;
%mend;

%macro ms_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MS_setup.sas ;

/* table 2 panels 1 and 2 (the table program) */
* from MS_link.sas ;
/* MS_link.sas - INCLUDE ONLY.  ASCII only.
   The survey link models of the table program: common dataset LK; TABLE 2 PANEL 1 (weighted R2 of the
   five definitions, both waves); TABLE 2 PANEL 2 (the three component models = manuscript table S2 rows across
   practices, opening hours, within practices and the falsification test).
   Creates: LK; T2R2 (tag A B As Bs W, r2_25 r2_26 n_25 n_26); T2P2 (model, var, coef, se, lo, hi, r2, n), with
   model in a25 a26 a26h fd fals. */

/* LK : the survey link; W recomputed from the three published components (as the table program) */
data LK;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
run;

/* TABLE 2 PANEL 1: one definition at a time */
%macro r2def(yr, tag, out);
    %local d v;
    data _s; set LK; where A_&tag ne . and ease_&yr ne .; run;
    %do d = 1 %to 5;
        %let v = %scan(A B As Bs W, &d);
        %wls(data=_s, y=ease_&yr, x=&v._&tag, w=n_eval_&yr, out=_o&d, tag=&v);
        data _o&d; set _o&d; where var ne 'Intercept'; run;
    %end;
    data &out; set _o1-_o5; run;
%mend;
%r2def(2025, w25, _p1a);
%r2def(2026, w26, _p1b);
proc sql;
    create table T2R2 as
    select a.tag length=4, a.r2 as r2_25, a.n as n_25, b.r2 as r2_26, b.n as n_26
    from _p1a a inner join _p1b b on a.tag = b.tag;
quit;

/* TABLE 2 PANEL 2: three components */
data _s25;  set LK; where A_w25  ne . and ease_2025 ne .; run;
data _s26;  set LK; where A_w26  ne . and ease_2026 ne .; run;
data _s26h; set LK; where Ah_w26 ne . and ease_2026 ne .; run;
%wls(data=_s25,  y=ease_2025, x=A_w25  cb_w25  menu_w25,  w=n_eval_2025, out=_m1, tag=a25);
%wls(data=_s26,  y=ease_2026, x=A_w26  cb_w26  menu_w26,  w=n_eval_2026, out=_m2, tag=a26);
%wls(data=_s26h, y=ease_2026, x=Ah_w26 cbh_w26 menuh_w26, w=n_eval_2026, out=_m3, tag=a26h);
data _chg;
    set LK;
    where n_months_w25 >= 2 and n_months_w26 >= 2 and ease_2025 ne . and ease_2026 ne .;
    dY    = ease_2026 - ease_2025;
    dA    = A_w26    - A_w25;
    dcb   = cb_w26   - cb_w25;
    dmenu = menu_w26 - menu_w25;
    wmin  = min(n_eval_2025, n_eval_2026);
    if ease_2024 ne . then dY_prev = ease_2025 - ease_2024;
run;
%wls(data=_chg, y=dY,      x=dA dcb dmenu, w=wmin, out=_m4, tag=fd);
%wls(data=_chg, y=dY_prev, x=dA dcb dmenu, w=wmin, out=_m5, tag=fals);
data T2P2;
    length model $8 comp $4;
    set _m1 _m2 _m3 _m4 _m5;
    model = tag;
    if      index(var, 'menu') then comp = 'menu';
    else if index(var, 'cb')   then comp = 'cb';
    else if index(var, 'A')    then comp = 'A';
    else comp = 'int';
    lo = coef - 1.96 * se; hi = coef + 1.96 * se;
    keep model comp var coef se lo hi r2 n;
run;
* end of MS_link.sas ;

/* check program 24 parts 3, 4, 5 */
%let C24P1 = 0; %let C24P2 = 0; %let C24P3 = 1; %let C24P4 = 1; %let C24P5 = 1;
* from MS_c24.sas ;
/* MS_c24.sas - INCLUDE ONLY.  ASCII only.
   Parts of check program 24 (identical in the min100 and unrestricted survey link runs; 24b = part 2 with more
   decimals).  Set before the include which parts to run (1 = run):
     C24P1  part 1, time cells with bank holidays and 22 December to 2 January removed (reads PERM.DT_ALL, slow)
            -> C24_P1 (model level rr_orig lcl_orig ucl_orig rr_xh lcl_xh ucl_xh inside in_rule)
     C24P2  part 2, practices sharing a postcode, site fixed effect, SE clustered by site (PROC SURVEYREG)
            -> C24_P2 (spec Parameter Estimate LowerCL UpperCL)
     C24P3  part 3, within-practice models: falsification test with 2025 levels, adjustment for 2024 ease and for
            the 2024 to 2025 change -> C24_P3 (tag var coef lo hi r2 n)
     C24P4  part 4, covariate-adjusted R2, 2026, bootstrap of the W - A difference (seed 20261005)
            -> C24_P4 (tag r2_adj increment), C24_P4B (r2_base), C24_P4D (diff p2_5 p97_5)
     C24P5  part 5, R2 of each definition and of W as (inbound - answered)/inbound -> C24_P5 (wave tag r2 n)
   Uses the library PERM as set by the caller. */

/* helper macros (as in check program 24) */
%macro mkXA(in, out);
    proc sql;
        create table _keep as
        select practice from &in
        where month >= "202510" group by practice having sum(CBT001) >= 1000;
    quit;
    data &out;
        set &in;
        where month >= "202510";
        if _n_ = 1 then do;
            declare hash k(dataset:'_keep'); k.definekey('practice'); k.definedone();
        end;
        if k.check() ne 0 then delete;
    run;
%mend;
%macro runfe(ds, s);
    %fe_cr0(data=&ds, num=CBT004,               den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
            gid=catx('|', practice, month), cid=practice, out=f&s.A, label=A);
    %fe_cr0(data=&ds, num=CBT004+CBT005,        den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
            gid=catx('|', practice, month), cid=practice, out=f&s.B, label=B);
    %fe_cr0(data=&ds, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
            gid=catx('|', practice, month), cid=practice, out=f&s.W, label=W);
    data f&s; length model $50 level $30; set f&s.A f&s.B f&s.W; run;
%mend;
%macro wold(months, tag);
    proc sql;
        create table _wo_&tag as
        select practice_code,
               100*(sum(cbt001_inbound)-sum(cbt003_answered))/sum(cbt001_inbound) as W_old_&tag
        from perm.practice_month
        where cbt_observed = 1 and cbt001_inbound > 0 and month in (&months)
        group by practice_code;
    quit;
    proc sort data=_wo_&tag; by practice_code; run;
%mend;
%macro glmr2(ds, x, tag, out, by=);
    proc glm data=&ds;
        %if %length(&by) %then %do; by &by; %end;
        class region_code;
        weight n_eval_2026;
        model ease_2026 = list_w26 calls_w26 imd region_code &x / solution;
        ods output FitStatistics=_fs;
    run; quit;
    data &out; length tag $24; set _fs; tag = "&tag"; keep &by tag RSquare; run;
%mend;
%macro r2four(yr, tag, out);
    %local d v;
    data _s; set LK24; where A_&tag ne . and ease_&yr ne .; run;
    %do d = 1 %to 6;
        %let v = %scan(A B As Bs W W_old, &d);
        %wls(data=_s, y=ease_&yr, x=&v._&tag, w=n_eval_&yr, out=_q&d, tag=&v);
    %end;
    data &out; length wave $4 tag $40; set _q1-_q6; where var ne 'Intercept'; wave = "&yr"; run;
%mend;

%macro _c24;

%if &C24P1 = 1 %then %do;
    data _bh;   /* holiday list = 06_daytime_db.sas (type of day analysis) */
        format d yymmdd10.;
        do d = '25DEC2024'd, '26DEC2024'd, '01JAN2025'd, '18APR2025'd, '21APR2025'd, '05MAY2025'd, '26MAY2025'd,
               '25AUG2025'd, '25DEC2025'd, '26DEC2025'd, '01JAN2026'd, '03APR2026'd, '06APR2026'd, '04MAY2026'd,
               '25MAY2026'd;
            output;
        end;
    run;
    data _cellsxh;
        if _n_ = 1 then do;
            if 0 then set _bh;
            declare hash h(dataset:'_bh'); h.definekey('d'); h.definedone();
        end;
        set perm.dt_all(keep=practice dt month_n dow band indicator value);
        where practice ne 'Unassigned' and 2 <= dow <= 6
          and indicator in ('CBT001','CBT002','CBT004','CBT005');
        if h.check(key:dt) = 0 then delete;
        if (month(dt) = 12 and day(dt) >= 22) or (month(dt) = 1 and day(dt) <= 2) then delete;
        length cell $12;
        if      band = '06:00-07:59' then cell = 'pre8';
        else if band = '08:00-09:59' then do;
            if dow = 2 then cell = 'rush_Mon'; else cell = 'rush_TueFri';
        end;
        else if band in ('10:00-11:59','12:00-13:59','14:00-15:59') then cell = 'midday';
        else if band in ('16:00-17:59','18:00-18:29') then cell = 'late';
        else delete;
        keep practice dt month_n cell indicator value;
    run;
    proc sql;
        create table cell_xh as
        select practice, month_n as month length=6, cell,
               sum(case when indicator='CBT001' then value else 0 end) as CBT001,
               sum(case when indicator='CBT002' then value else 0 end) as CBT002,
               sum(case when indicator='CBT004' then value else 0 end) as CBT004,
               sum(case when indicator='CBT005' then value else 0 end) as CBT005
        from _cellsxh group by practice, month_n, cell;
    quit;
    proc datasets lib=work nolist; delete _cellsxh; quit;
    %mkXA(perm.cell_daytime, XA0);
    %mkXA(cell_xh,           XA1);
    %runfe(XA0, 0);
    %runfe(XA1, 1);
    proc sql;
        create table C24_P1 as
        select a.model, a.level,
               a.rr as rr_orig, a.lcl as lcl_orig, a.ucl as ucl_orig,
               b.rr as rr_xh,   b.lcl as lcl_xh,   b.ucl as ucl_xh,
               (b.rr between a.lcl and a.ucl) as inside,
               (a.level ne 'pre8')      as in_rule
        from f0 a inner join f1 b on a.model = b.model and a.level = b.level
        order by a.model, a.level;
    quit;
%end;

%if &C24P2 = 1 or &C24P3 = 1 or &C24P4 = 1 or &C24P5 = 1 %then %do;
    /* old W formula (inbound - answered)/inbound, as 14_external_link.sas */
    %wold(%str('202501','202502','202503'), w25);
    %wold(%str('202601','202602','202603'), w26);
    proc sort data=perm.ext_link out=_el; by practice_code; run;
    data LK24;
        merge _el(in=e) _wo_w25 _wo_w26;
        by practice_code;
        if e;
        W_w25 = A_w25 + cb_w25 + menu_w25;
        W_w26 = A_w26 + cb_w26 + menu_w26;
    run;
%end;

%if &C24P2 = 1 %then %do;
    data _site;
        set LK24;
        where A_w26 ne . and ease_2026 ne . and postcode ne '';
        pc = upcase(compress(postcode));
    run;
    proc sql;
        create table _site2 as
        select a.*, b.nsite,
               a.ease_2026 - b.mY as y_dm, a.A_w26 - b.mA as A_dm,
               a.cb_w26 - b.mcb as cb_dm, a.menu_w26 - b.mmenu as menu_dm
        from _site a inner join
             (select pc, count(*) as nsite, mean(ease_2026) as mY, mean(A_w26) as mA,
                     mean(cb_w26) as mcb, mean(menu_w26) as mmenu
              from _site group by pc having count(*) >= 2) b
        on a.pc = b.pc;
    quit;
    data _site2; set _site2; one = 1; run;
    proc surveyreg data=_site2;
        class pc;
        model ease_2026 = A_w26 cb_w26 menu_w26 pc / solution clparm;
        cluster pc;
        ods output ParameterEstimates=_s2u;
    run;
    data C24_P2;
        length spec $30;
        set _s2u;
        where Parameter in ('A_w26', 'cb_w26', 'menu_w26');
        spec = 'site FE, unweighted';
        keep spec Parameter Estimate LowerCL UpperCL;
    run;
%end;

%if &C24P3 = 1 %then %do;
    data _chg;
        set LK24;
        where n_months_w25 >= 2 and n_months_w26 >= 2 and ease_2025 ne . and ease_2026 ne .;
        dY    = ease_2026 - ease_2025;
        dA    = A_w26    - A_w25;
        dcb   = cb_w26   - cb_w25;
        dmenu = menu_w26 - menu_w25;
        wmin  = min(n_eval_2025, n_eval_2026);
        wprev = min(n_eval_2024, n_eval_2025);
        if ease_2024 ne . then dY_prev = ease_2025 - ease_2024;
    run;
    %wls(data=_chg, y=dY_prev, x=dA dcb dmenu A_w25 cb_w25 menu_w25,   w=wprev, out=_c1, tag=%str(levels));
    %wls(data=_chg, y=dY,      x=dA dcb dmenu ease_2024,               w=wmin, out=_c2, tag=%str(ease2024));
    %wls(data=_chg, y=dY,      x=dA dcb dmenu dY_prev,                 w=wmin, out=_c3, tag=%str(dYprev));
    data C24_P3;
        length tag $40;
        set _c1 _c2 _c3;
        lo = coef - 1.96 * se; hi = coef + 1.96 * se;
        keep tag var coef se lo hi r2 n;
    run;
%end;

%if &C24P4 = 1 %then %do;
    data _r4;
        set LK24;
        where ease_2026 ne . and n_eval_2026 > 0 and A_w26 ne . and B_w26 ne . and As_w26 ne .
          and Bs_w26 ne . and W_w26 ne . and list_w26 ne . and calls_w26 ne . and imd ne .
          and region_code ne '';
    run;
    %glmr2(_r4, ,                       base, _g0);
    %glmr2(_r4, A_w26,                  A,    _g1);
    %glmr2(_r4, B_w26,                  B,    _g2);
    %glmr2(_r4, As_w26,                 As,   _g3);
    %glmr2(_r4, Bs_w26,                 Bs,   _g4);
    %glmr2(_r4, W_w26,                  W,    _g5);
    proc sql;
        create table C24_P4B as select RSquare as r2_base, (select count(*) from _r4) as n from _g0;
        create table C24_P4 as
        select a.tag, a.RSquare as r2_adj, a.RSquare - b.RSquare as increment
        from (select * from _g1 union all select * from _g2 union all select * from _g3
              union all select * from _g4 union all select * from _g5) a, _g0 b;
    quit;
    proc surveyselect data=_r4 out=_rb method=urs samprate=1 reps=2000 outhits seed=20261005 noprint;
    run;
    %glmr2(_rb, A_w26, A, _b1, by=Replicate);
    %glmr2(_rb, W_w26, W, _b5, by=Replicate);
    proc sql;
        create table _bd as
        select a.Replicate, b.RSquare - a.RSquare as d
        from _b1 a inner join _b5 b on a.Replicate = b.Replicate;
    quit;
    proc univariate data=_bd noprint;
        var d; output out=_bq pctlpts=2.5 97.5 pctlpre=p n=nrep;
    run;
    proc sql;
        create table C24_P4D as
        select q.p2_5, q.p97_5, w.r2_adj - a.r2_adj as diff
        from _bq q, C24_P4 w, C24_P4 a
        where w.tag = 'W' and a.tag = 'A';
    quit;
%end;

%if &C24P5 = 1 %then %do;
    %r2four(2025, w25, _f25);
    %r2four(2026, w26, _f26);
    data C24_P5; set _f25 _f26; keep wave tag r2 n; run;
%end;
%mend _c24;
%_c24;
* end of MS_c24.sas ;

/* check program 25c 7-4, check program 25 parts 3 and 4, check program 26 part 9-2 */
%let C25P1 = 0; %let C25C74 = 1; %let C25P3 = 1; %let C25P4 = 1; %let C26P92 = 1;
* from MS_c25.sas ;
/* MS_c25.sas - INCLUDE ONLY.  ASCII only.
   Parts of check program 25, check program 25b, check program 25c and
   check program 26 (the four programs share the same first steps: LK sorted by practice, the
   durations files read into DUR, DURP and LKD).  Set before the include (1 = run):
     C25P1   check program 25 part 1c/1d (= 25b): R2 of A, W, L2 (answered after more than 2 min), L5 (more than 5 min) on
             the common sample, bootstrap of R2(W) - R2(L2) (seed 20261006)  -> C25_R2 (wave tag r2 n), C25_BQ
     C25C74  check program 25c 7-4: three component model with and without the waiting time share -> C25_74
     C25P3   check program 25 part 3: extended covariates (workforce, online consultation, GPAD appointments, age 65+),
             W - A increment difference with bootstrap (seed 20261006) -> C25_P3 (variant n d_W_A p2_5 p97_5)
     C25P4   check program 25 part 4b: R2(W) - R2(A) with networks resampled (seed 20261006) -> C25_P4 (wave p2_5 p97_5)
     C26P92  check program 26 part 9-2: covariate adjusted three component model, HC1 -> C26_92 (var coef lo hi r2 n)
   Uses the library PERM as set by the caller. */

%let SEED25  = 20261006;
%let NBOOT25 = 2000;

%macro readdur(mon, yr, tag);
    %local r rg;
    %do r = 1 %to 7;
        %let rg = %scan(Y56 Y58 Y59 Y60 Y61 Y62 Y63, &r);
        data _d;
            length practice $10 indicator $10 dur $12;
            infile "&CBTDIR.\Cloud Based Telephony By Durations - &mon. &yr._&rg..csv" dsd truncover firstobs=2 lrecl=2048;
            input dt : yymmdd10. region_code : $10. icb : $20. sub_icb : $20. pcn : $20. practice $ indicator $ dur $ value;
            if missing(value) then value = 0;
            if practice = 'Unassigned' then delete;   /* shared-account calls, as PERM.DT_ALL */
            keep practice indicator dur value;
        run;
        proc sql;
            create table _a as
            select practice,
                   sum(case when indicator='CBT001' then value else 0 end) as inb,
                   sum(case when indicator='CBT003' then value else 0 end) as ans,
                   sum(case when indicator='CBT003' and dur in ('121_180','181_240','241_300','>300') then value else 0 end) as ans120,
                   sum(case when indicator='CBT003' and dur = '>300' then value else 0 end) as ans300,
                   sum(case when indicator='CBT004' then value else 0 end) as mis,
                   sum(case when indicator='CBT004' and dur in ('121_180','181_240','241_300','>300') then value else 0 end) as mis120
            from _d group by practice;
        quit;
        data _a; length wave $3 mon $16; set _a; wave = "&tag"; mon = "&mon.&yr"; run;
        proc append base=DUR data=_a force; run;
    %end;
%mend;

%macro r2set(yr, tag);
    data _s&tag; set LKD;
        where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne . and W_&tag ne . and L2_&tag ne .
          and L5_&tag ne . and M2_&tag ne .;
        y = ease_&yr; w = n_eval_&yr; xA = A_&tag; xW = W_&tag; L2 = L2_&tag; L5 = L5_&tag; M2 = M2_&tag;
        keep practice_code pcl y w xA xW L2 L5 M2;
    run;
    %local d v;
    %do d = 1 %to 5;
        %let v = %scan(xA xW L2 L5 M2, &d);
        %wls(data=_s&tag, y=y, x=&v, w=w, out=_r&d, tag=&v);
    %end;
    data r2_&tag; length tag $40 wave $4; set _r1-_r5; wave = "&yr"; run;
%mend;
%macro r2boot(tag);
    proc surveyselect data=_s&tag out=_b&tag method=urs samprate=1 reps=&NBOOT25 outhits seed=&SEED25 noprint; run;
    %local m;
    %do m = 1 %to 4;
        proc reg data=_b&tag outest=_e&m(keep=Replicate _RSQ_) rsquare noprint;
            by Replicate; weight w;
            %if &m = 1 %then %do; model y = xA; %end;
            %if &m = 2 %then %do; model y = xW; %end;
            %if &m = 3 %then %do; model y = L2; %end;
            %if &m = 4 %then %do; model y = xW L2; %end;
        run; quit;
        data _e&m; set _e&m; rename _RSQ_ = r&m; run;
    %end;
    data _bd&tag; merge _e1 _e2 _e3 _e4; by Replicate;
        d_L2_A = r3 - r1; d_W_L2 = r2 - r3; inc_L2 = r4 - r2;
    run;
    proc univariate data=_bd&tag noprint;
        var d_L2_A d_W_L2 inc_L2;
        output out=_bq&tag pctlpts=2.5 97.5 pctlpre=LA_ WL_ IN_;
    run;
%mend;
%macro comp4(yr, tag);
    data _q&tag; set LKD; where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne . and L2_&tag ne .;
        y = ease_&yr; w = n_eval_&yr; xA = A_&tag; xcb = cb_&tag; xmenu = menu_&tag; L2 = L2_&tag; run;
    %wls(data=_q&tag, y=y, x=xA xcb xmenu,    w=w, out=_k1, tag=%str(&yr three));
    %wls(data=_q&tag, y=y, x=xA xcb xmenu L2, w=w, out=_k2, tag=%str(&yr plusL2));
    data k_&tag; length tag $40; set _k1 _k2; where var ne 'Intercept'; run;
%mend;
%macro rdgpad(file, wave, mon);
    data _g;
        length gp $10 a1-a12 $200 cnt 8;
        infile "&ROOT.\GPAD DB\&file" dsd truncover firstobs=2 lrecl=4096;
        input a1 $ gp $ a2 $ a3 $ a4 $ a5 $ a6 $ a7 $ a8 $ a9 $ a10 $ a11 $ cnt a12 $;
        keep gp cnt;
    run;
    proc sql; create table _gs as select gp as practice_code length=10, sum(cnt) as appts from _g group by gp; quit;
    data _gs; length wave $3 src $80 mon $6; set _gs; wave = "&wave"; src = "&file"; mon = "&mon"; run;
    proc append base=GPAD data=_gs force; run;
%mend;
%macro glmr2c(ds, x, tag, out, covs=, by=);
    proc glm data=&ds;
        %if %length(&by) %then %do; by &by; %end;
        class region_code;
        weight wgt;
        model y = &covs region_code &x;
        ods output FitStatistics=_fs;
    run; quit;
    data &out; length tag $24; set _fs; tag = "&tag"; keep &by tag RSquare; run;
%mend;
%macro covvar(vname, yr, tag, covs, where=1);
    data _c; set LKC;
        where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne . and B_&tag ne . and As_&tag ne . and Bs_&tag ne .
          and W_&tag ne . and list_&tag ne . and calls_&tag ne . and imd ne . and region_code ne ''
          and gp_&tag ne . and rec_&tag ne . and loc_&tag ne . and appt_&tag ne . and s65_&tag ne . and &where;
        y = ease_&yr; wgt = n_eval_&yr; A = A_&tag; B = B_&tag; As = As_&tag; Bs = Bs_&tag; W = W_&tag;
        lst = list_&tag; cls = calls_&tag; gp = gp_&tag; rec = rec_&tag; loc = loc_&tag; appt = appt_&tag; s65 = s65_&tag;
    run;
    %glmr2c(_c, ,   base, _g0, covs=&covs);
    %glmr2c(_c, A,  A,  _g1, covs=&covs);
    %glmr2c(_c, B,  B,  _g2, covs=&covs);
    %glmr2c(_c, As, As, _g3, covs=&covs);
    %glmr2c(_c, Bs, Bs, _g4, covs=&covs);
    %glmr2c(_c, W,  W,  _g5, covs=&covs);
    proc sql noprint; select count(*) into :_nc trimmed from _c; quit;
    proc sql;
        create table _inc as
        select "&vname" as variant length=40, &_nc as n, b.RSquare as r2_base, a.tag, a.RSquare - b.RSquare as increment
        from (select * from _g1 union all select * from _g2 union all select * from _g3 union all select * from _g4
              union all select * from _g5) a, _g0 b;
    quit;
    proc append base=P3INC data=_inc force; run;
    proc surveyselect data=_c out=_cb method=urs samprate=1 reps=&NBOOT25 outhits seed=&SEED25 noprint; run;
    %glmr2c(_cb, A, A, _cbA, covs=&covs, by=Replicate);
    %glmr2c(_cb, W, W, _cbW, covs=&covs, by=Replicate);
    data _cbd; merge _cbA(rename=(RSquare=rA)) _cbW(rename=(RSquare=rW)); by Replicate; d = rW - rA; run;
    proc univariate data=_cbd noprint; var d; output out=_cbq pctlpts=2.5 97.5 pctlpre=p; run;
    data _cbq; length variant $40; set _cbq; variant = "&vname"; run;
    proc append base=P3BOOT data=_cbq force; run;
%mend;
%macro pcnreg(yr, tag);
    data _p; set LK25; where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne .;
        y = ease_&yr; wgt = n_eval_&yr; A = A_&tag; cb = cb_&tag; menu = menu_&tag; W = W_&tag; run;
    proc sql; create table _pc as select distinct pcl from _p; quit;
    proc surveyselect data=_pc out=_pcb method=urs samprate=1 reps=&NBOOT25 outhits seed=&SEED25 noprint; run;
    proc sql; create table _pb as select b.Replicate, a.* from _pcb b inner join _p a on a.pcl = b.pcl order by b.Replicate; quit;
    proc reg data=_pb outest=_q1(keep=Replicate _RSQ_ rename=(_RSQ_=rA)) rsquare noprint; by Replicate; weight wgt; model y = A; run; quit;
    proc reg data=_pb outest=_q2(keep=Replicate _RSQ_ rename=(_RSQ_=rW)) rsquare noprint; by Replicate; weight wgt; model y = W; run; quit;
    data _qd; merge _q1 _q2; by Replicate; d = rW - rA; run;
    proc univariate data=_qd noprint; var d; output out=_qq&tag pctlpts=2.5 97.5 pctlpre=p; run;
    data _qq&tag; length wave $4; set _qq&tag; wave = "&yr"; run;
%mend;

%macro _c25;
/* LK: survey link, W as the sum of the three components; network cluster (as check program 25) */
data LK25;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
    length pcl $10;
    pcl = coalescec(pcn_code, practice_code);
run;
proc sort data=LK25; by practice_code; run;

%if &C25P1 = 1 or &C25C74 = 1 or &C25P3 = 1 %then %do;
    proc datasets lib=work nolist nowarn; delete DUR; quit;
    %readdur(January,  2025, w25); %readdur(February, 2025, w25); %readdur(March, 2025, w25);
    %readdur(January,  2026, w26); %readdur(February, 2026, w26); %readdur(March, 2026, w26);
    proc sql;
        create table DURP as
        select practice as practice_code length=10, wave,
               sum(inb) as inb, sum(ans) as ans, sum(ans120) as ans120, sum(ans300) as ans300, sum(mis120) as mis120
        from DUR group by practice, wave;
    quit;
    data DURP; set DURP;
        if ans > 0 then do; L2 = 100 * ans120 / ans; L5 = 100 * ans300 / ans; end;
        if inb > 0 then M2 = 100 * mis120 / inb;
    run;
    proc sql;
        create table LKD as
        select a.*, b.L2 as L2_w25, b.L5 as L5_w25, b.M2 as M2_w25, c.L2 as L2_w26, c.L5 as L5_w26, c.M2 as M2_w26
        from LK25 a left join DURP(where=(wave='w25')) b on a.practice_code = b.practice_code
                  left join DURP(where=(wave='w26')) c on a.practice_code = c.practice_code;
    quit;
%end;

%if &C25P1 = 1 %then %do;
    %r2set(2025, w25);
    %r2set(2026, w26);
    data C25_R2; set r2_w25 r2_w26; where var ne 'Intercept'; keep wave tag coef r2 n; run;
    %r2boot(w25);
    %r2boot(w26);
    data C25_BQ; length wave $4; set _bqw25(in=a) _bqw26; wave = ifc(a, '2025', '2026'); run;
%end;

%if &C25C74 = 1 %then %do;
    %comp4(2025, w25);
    %comp4(2026, w26);
    data C25_74; set k_w25 k_w26; lo = coef - 1.96 * se; hi = coef + 1.96 * se; keep tag var coef se lo hi r2 n; run;
%end;

%if &C25P3 = 1 %then %do;
    proc datasets lib=work nolist nowarn; delete GPAD P3INC P3BOOT; quit;
    %rdgpad(Practice_Level_Crosstab_Jan_25.csv, w25, 202501);
    %rdgpad(Practice_Level_Crosstab_Feb_25.csv, w25, 202502);
    %rdgpad(Practice_Level_Crosstab_Mar_25.csv, w25, 202503);
    %rdgpad(Practice_Level_Crosstab_Jan_26.csv, w26, 202601);
    %rdgpad(Practice_Level_Crosstab_Feb_26.csv, w26, 202602);
    %rdgpad(Practice_Level_Crosstab_London_East_South_Mar_26.csv, w26, 202603);
    %rdgpad(Practice_Level_Crosstab_Midlands_North_Mar_26.csv, w26, 202603);
    proc sql; create table GPADW as select practice_code, wave, sum(appts) / count(distinct mon) as appts_month from GPAD group by practice_code, wave; quit;
    proc sql;
        create table COVW as
        select practice_code,
               case when month in ('202501','202502','202503') then 'w25' else 'w26' end as wave length=3,
               mean(list_size) as lsz, mean(gp_fte_qualified) as gpfte, mean(reception_fte) as recfte,
               mean(oc_rate_per_1000) as ocr, mean(share_65plus) as s65
        from perm.practice_month
        where month in ('202501','202502','202503','202601','202602','202603')
        group by practice_code, calculated wave;
        create table COV as
        select a.*, 1000 * a.gpfte / a.lsz as gp1000, 1000 * a.recfte / a.lsz as rec1000, log(1 + a.ocr) as loc,
               1000 * b.appts_month / a.lsz as appt1000
        from COVW a left join GPADW b on a.practice_code = b.practice_code and a.wave = b.wave
        where a.lsz > 0;
    quit;
    proc sql;
        create table LKC as
        select l.*, c5.gp1000 as gp_w25, c5.rec1000 as rec_w25, c5.loc as loc_w25, c5.appt1000 as appt_w25, c5.s65 as s65_w25,
                    c6.gp1000 as gp_w26, c6.rec1000 as rec_w26, c6.loc as loc_w26, c6.appt1000 as appt_w26, c6.s65 as s65_w26,
               (l.ease_2025 ne . and l.A_w25 ne .) as in25
        from LKD l left join COV(where=(wave='w25')) c5 on l.practice_code = c5.practice_code
                   left join COV(where=(wave='w26')) c6 on l.practice_code = c6.practice_code;
    quit;
    %covvar(2026 full,                 2026, w26, %str(lst cls imd gp rec loc appt s65));
    %covvar(2026 without calls,        2026, w26, %str(lst imd gp rec loc appt s65));
    %covvar(2025 full,                 2025, w25, %str(lst cls imd gp rec loc appt s65));
    proc sql;
        create table _p3d as
        select a.variant, a.n, max(case when a.tag='W' then a.increment end) - max(case when a.tag='A' then a.increment end) as d_W_A
        from P3INC a group by a.variant, a.n;
        create table C25_P3 as select a.*, b.p2_5, b.p97_5 from _p3d a inner join P3BOOT b on a.variant = b.variant;
    quit;
%end;

%if &C25P4 = 1 %then %do;
    %pcnreg(2025, w25);
    %pcnreg(2026, w26);
    data C25_P4; set _qqw25 _qqw26; run;
%end;

%if &C26P92 = 1 %then %do;
    proc sql noprint;
        select distinct region_code into :REGS separated by ' ' from LK25 where region_code ne '' order by region_code;
    quit;
    data _r92;
        set LK25;
        where ease_2026 ne . and n_eval_2026 > 0 and A_w26 ne . and B_w26 ne . and As_w26 ne .
          and Bs_w26 ne . and W_w26 ne . and list_w26 ne . and calls_w26 ne . and imd ne .
          and region_code ne '';
        array rg{7} rg1-rg7;
        do _i = 1 to 7; rg{_i} = (region_code = scan("&REGS", _i, ' ')); end;
    run;
    %wls(data=_r92, y=ease_2026, x=A_w26 cb_w26 menu_w26 list_w26 calls_w26 imd rg2 rg3 rg4 rg5 rg6 rg7, w=n_eval_2026, out=_q92, tag=%str(adjusted HC1 2026));
    data C26_92; set _q92; lo = coef - 1.96 * se; hi = coef + 1.96 * se; keep var coef se lo hi r2 n; run;
%end;
%mend _c25;
%_c25;
* end of MS_c25.sas ;

/* Wald tests of equal within-practice coefficients, HC1 (analysis program 09 part D) */
data _chgw;
    set perm.ext_link;
    where n_months_w25 >= 2 and n_months_w26 >= 2 and ease_2025 ne . and ease_2026 ne .;
    dY    = ease_2026 - ease_2025;
    dA    = A_w26    - A_w25;
    dcb   = cb_w26   - cb_w25;
    dmenu = menu_w26 - menu_w25;
    wmin  = min(n_eval_2025, n_eval_2026);
run;
proc reg data=_chgw;
    weight wmin;
    model dY = dA dcb dmenu / hcc hccmethod=1;
    menu_v_aband: test dmenu = dA;
    cb_v_aband:   test dcb = dA;
    ods output ACovTestANOVA=_wald;
run; quit;
data _wald; length wtest $16; set _wald; wtest = strip(Test); run;

/* collinearity of the three component models (the table program VIF_CHECK) */
data _v25; set LK; where A_w25 ne . and ease_2025 ne .; run;
data _v26; set LK; where A_w26 ne . and ease_2026 ne .; run;
data _vch;
    set LK;
    where n_months_w25 >= 2 and n_months_w26 >= 2
      and ease_2025 ne . and ease_2026 ne .;
    dY    = ease_2026 - ease_2025;
    dA    = A_w26    - A_w25;
    dcb   = cb_w26   - cb_w25;
    dmenu = menu_w26 - menu_w25;
    wmin  = min(n_eval_2025, n_eval_2026);
run;
proc reg data=_v26 plots=none;
    weight n_eval_2026;
    model ease_2026 = A_w26 cb_w26 menu_w26 / vif tol collinoint;
    ods output ParameterEstimates=_pe26 CollinDiagNoInt=_cd26;
run; quit;
proc reg data=_v25 plots=none;
    weight n_eval_2025;
    model ease_2025 = A_w25 cb_w25 menu_w25 / vif tol collinoint;
    ods output ParameterEstimates=_pe25 CollinDiagNoInt=_cd25;
run; quit;
proc reg data=_vch plots=none;
    weight wmin;
    model dY = dA dcb dmenu / vif tol collinoint;
    ods output ParameterEstimates=_pech CollinDiagNoInt=_cdch;
run; quit;
proc sql;
    create table _vif as
    select min(VarianceInflation) as vif_lo, max(VarianceInflation) as vif_hi
    from (select VarianceInflation from _pe26 where Variable ne 'Intercept'
          union all select VarianceInflation from _pe25 where Variable ne 'Intercept'
          union all select VarianceInflation from _pech where Variable ne 'Intercept');
quit;
data _cdall; set _cd26 _cd25 _cdch; keep ConditionIndex; run;
proc sql;
    create table _cix as select max(ConditionIndex) as ci_max from _cdall;
quit;

/* year to year correlation of the ease item (the table program FOOTNOTE NUMBERS) */
proc sql;
    create table _ry as
    select (mean(ease_2025 * ease_2026) - mean(ease_2025) * mean(ease_2026)) /
           (std(ease_2025) * std(ease_2026)) * (count(*) / (count(*) - 1)) as r_year
    from LK where ease_2025 ne . and ease_2026 ne .;
/* practices in the 2026 three component model without 2025 telephony in the survey link */
    create table _no25 as
    select sum(A_w25 = .) as n_no25 from LK where A_w26 ne . and ease_2026 ne .;
quit;


/* ---- results, in the order of the table ---- */
%macro row3(o, lab, ds, wh, a, c, m, dp=2, sgn=0, r2ds=, r2wh=);
    %local f;
    %if &sgn = 1 %then %let f = cis; %else %let f = ci;
    %add(%eval(&o + 1), Rows, &lab, Abandoned,         &f(coef, lo, hi, &dp), ds=&ds, wh=%str(&wh and var="&a"));
    %add(%eval(&o + 2), Rows, &lab, Callback diverted, &f(coef, lo, hi, &dp), ds=&ds, wh=%str(&wh and var="&c"));
    %add(%eval(&o + 3), Rows, &lab, Menu ended,        &f(coef, lo, hi, &dp), ds=&ds, wh=%str(&wh and var="&m"));
    %add(%eval(&o + 4), Rows, &lab, R2,                fn(r2, 2),             ds=&ds, wh=%str(&wh and var="&a"));
    %add(%eval(&o + 5), Rows, &lab, n,                 fi(n),                 ds=&ds, wh=%str(&wh and var="&a"));
%mend;
%row3(100,  %str(Across practices, 2025),               T2P2,   %str(model='a25'),  A_w25,  cb_w25,  menu_w25);
%row3(110,  %str(Across practices, 2026),               T2P2,   %str(model='a26'),  A_w26,  cb_w26,  menu_w26);
%row3(120,  %str(Across practices, 2026, opening hours), T2P2,  %str(model='a26h'), Ah_w26, cbh_w26, menuh_w26);
%row3(130,  %str(Across practices, 2026, adjusted for list size, calls per 1000 patients, deprivation, and region),
            C26_92, %str(1), A_w26, cb_w26, menu_w26);
%row3(140,  %str(Practices with waiting time data, 2025), C25_74, %str(tag='2025 three'),  xA, xcb, xmenu);
%row3(150,  %str(Same, adding the waiting time share, 2025), C25_74, %str(tag='2025 plusL2'), xA, xcb, xmenu);
%row3(160,  %str(Practices with waiting time data, 2026), C25_74, %str(tag='2026 three'),  xA, xcb, xmenu);
%row3(170,  %str(Same, adding the waiting time share, 2026), C25_74, %str(tag='2026 plusL2'), xA, xcb, xmenu);
%row3(180,  %str(Within practices, 2025 to 2026),       T2P2,   %str(model='fd'),   dA, dcb, dmenu);
%row3(190,  %str(Falsification test: 2024 to 2025 change in ease), T2P2, %str(model='fals'), dA, dcb, dmenu, sgn=1);
%row3(200,  %str(Falsification test with the 2025 levels added),   C24_P3, %str(tag='levels'), dA, dcb, dmenu, sgn=1);

%add(301, Footnote, Adjusted for 2024 ease, Menu ended,                         ci(coef, lo, hi, 2), ds=C24_P3, wh=%str(tag='ease2024' and var='dmenu'));
%add(302, Footnote, Adjusted for the 2024 to 2025 change in ease, Menu ended,   ci(coef, lo, hi, 2), ds=C24_P3, wh=%str(tag='dYprev' and var='dmenu'));
%add(303, Footnote, Wald test menu ended v abandoned (within practices), P,     strip(fn(ProbChiSq, 2)), ds=_wald, wh=%str(wtest='menu_v_aband'));
%add(304, Footnote, Wald test callback diverted v abandoned (within practices), P, strip(fn(ProbChiSq, 3)), ds=_wald, wh=%str(wtest='cb_v_aband'));
%add(311, Footnote, %str(Adjusted comparisons, 2026), practices,               fi(n), ds=C24_P4B);
%add(312, Footnote, %str(Adjusted comparisons, 2026), R2 of the covariates alone, fn(r2_base, 2), ds=C24_P4B);
%add(313, Footnote, %str(Adjusted comparisons, 2026), R2 increase - abandonment,                     fn(increment, 2), ds=C24_P4, wh=%str(tag='A'));
%add(314, Footnote, %str(Adjusted comparisons, 2026), R2 increase - real time non-connection,         fn(increment, 2), ds=C24_P4, wh=%str(tag='B'));
%add(315, Footnote, %str(Adjusted comparisons, 2026), R2 increase - queue restricted abandonment,     fn(increment, 2), ds=C24_P4, wh=%str(tag='As'));
%add(316, Footnote, %str(Adjusted comparisons, 2026), R2 increase - queue restricted non-connection,  fn(increment, 2), ds=C24_P4, wh=%str(tag='Bs'));
%add(317, Footnote, %str(Adjusted comparisons, 2026), R2 increase - total non-connection,             fn(increment, 2), ds=C24_P4, wh=%str(tag='W'));
%add(318, Footnote, %str(Adjusted comparisons, 2026), difference total non-connection minus abandonment, ci(diff, p2_5, p97_5, 2), ds=C24_P4D);
%add(321, Footnote, Extended covariates, practices 2026, fi(n), ds=C25_P3, wh=%str(variant='2026 full'));
%add(322, Footnote, Extended covariates, practices 2025, fi(n), ds=C25_P3, wh=%str(variant='2025 full'));
%add(323, Footnote, Extended covariates, difference total non-connection minus abandonment 2026, ci(d_W_A, p2_5, p97_5, 2), ds=C25_P3, wh=%str(variant='2026 full'));
%add(324, Footnote, Extended covariates, difference total non-connection minus abandonment 2025, ci(d_W_A, p2_5, p97_5, 2), ds=C25_P3, wh=%str(variant='2025 full'));
%add(325, Footnote, Extended covariates, difference 2026 without calls per 1000 patients,         ci(d_W_A, p2_5, p97_5, 2), ds=C25_P3, wh=%str(variant='2026 without calls'));
%add(326, Footnote, Unadjusted difference with networks resampled, 2026 interval, rng(p2_5, p97_5, 2), ds=C25_P4, wh=%str(wave='2026'));
%add(327, Footnote, Unadjusted difference with networks resampled, 2025 interval, rng(p2_5, p97_5, 2), ds=C25_P4, wh=%str(wave='2025'));
%add(331, Footnote, Total non-connection as all calls not answered by staff, R2 2025,           fn(r2, 2), ds=C24_P5, wh=%str(wave='2025' and tag='W_old'));
%add(332, Footnote, Total non-connection as all calls not answered by staff, R2 2025 (v main), fn(r2, 2), ds=C24_P5, wh=%str(wave='2025' and tag='W'));
%add(333, Footnote, Total non-connection as all calls not answered by staff, R2 2026 (old),    fn(r2, 2), ds=C24_P5, wh=%str(wave='2026' and tag='W_old'));
%add(334, Footnote, Total non-connection as all calls not answered by staff, R2 2026 (main),   fn(r2, 2), ds=C24_P5, wh=%str(wave='2026' and tag='W'));
%add(341, Footnote, Practices in 2026 without 2025 telephony, , fi(n_no25), ds=_no25);
%add(342, Footnote, Year-to-year practice correlation of the ease item, , fn(r_year, 2), ds=_ry);
%add(343, Footnote, Three component model R2, 2025, fn(r2, 2), ds=T2P2, wh=%str(model='a25' and var='A_w25'));
%add(344, Footnote, Three component model R2, 2026, fn(r2, 2), ds=T2P2, wh=%str(model='a26' and var='A_w26'));
%add(345, Footnote, Variance inflation factors, range, rng(vif_lo, vif_hi, 2), ds=_vif);
%add(346, Footnote, Largest condition index, , fn(ci_max, 2), ds=_cix);
%add(351, Footnote, Waiting time share coefficient, 2025, ci(coef, lo, hi, 2), ds=C25_74, wh=%str(tag='2025 plusL2' and var='L2'));
%add(352, Footnote, Waiting time share coefficient, 2026, ci(coef, lo, hi, 2), ds=C25_74, wh=%str(tag='2026 plusL2' and var='L2'));

%ms_write;

* Table S3 (TS3_tableS3) ;
%fresh;

/* TS3_tableS3.sas - Table S3. Summary of sensitivity and robustness analyses.
   Every number in table S3 (both value columns of every row), written to output\TS3_tableS3.txt.  The table
   transcribes results reported elsewhere; each row is recomputed here with the program that produced it:
     rows 1-3   five definitions, abandoned plus menu ended, Poisson: the table program TABLE S1 PANEL 1 and 2, check program 25
                part 2 (MS_s1cells.sas)
     row 4      daily source files: the table program TABLE 3 PANEL B (MS_tamisc.sas)
     row 5      bank holidays removed: check program 24 part 1 (MS_c24.sas)
     rows 6-7   periods: check program 27 (MS_c27.sas)
     rows 8-9   callback use and intensity: the table program TABLE S4 panels 1 and 3 (MS_tamisc.sas)
     row 10     variance components: check program 14 = analysis program 03 (MS_c14.sas)
     row 11     shared postcode: the table program TABLE S5 (MS_tamisc.sas), check program 24 part 2 / 24b (MS_c24.sas)
     row 12     practice covariates: check program 24 part 4, check program 25 parts 3 and 4 (MS_c24.sas, MS_c25.sas)
     row 13     waiting time: check program 25 part 1 = 25b (MS_c25.sas)
     row 14     all linked practices (unrestricted survey link, 3071 practices): check program 23 part C run on SAS_OUT
                (MS_c23c.sas)
     rows 15-17 telephony window, respondents, recorded outcomes: check program 31 parts 1-2, check program 32 parts 1 and 3
                (MS_c3132.sas)
     rows 18-19 within-practice change, falsification, opening hours: the table program TABLE 2 PANEL 2 (MS_link.sas),
                check program 24 part 3 (MS_c24.sas)
     row 20     balanced panel: check program 33 part 2b (MS_tamisc.sas)
     row 21     entry cohort: the table program TABLE S7 (MS_tamisc.sas)
     row 22     slope and relative index of inequality: check program 15 = analysis program 04 (MS_c15.sas), check program 27 (decile ratio)
   "Main estimate" values come from the table program (table 2, table 3 panel A, table S1, table S2).
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only), PERMO.EXT_LINK (SAS_OUT, for row 14 and the network codes
   of row 10), PERM.DT_ALL, the durations files and the GPAD files (read only).  ASCII only.
   Run: RUN_TS3_tableS3.bat (about 25 minutes). */

%let PROG = TS3_tableS3;
%let EXH  = Table S3;
* from MS_setup.sas ;
/* MS_setup.sas - common set-up for the supplementary table programs TS1 to TS5.  INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder), PROG (its own name) and EXH (the exhibit label) first.
   Does:  options; ODS output excluded (programs compute quietly); 00_paths.sas (one folder up);
          the estimator macros (MS_wls.sas, MS_fe_cr0.sas, MS_ppml.sas); number formatting functions;
          the results table RES, the macro %add that puts one number into it, and %ms_write that writes
          RES to output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;   /* nothing is printed; results go to RES and output\PROG.txt */

/* the output file of this table, in the folder OUT (PART 0) */
%macro _ms_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_ms_dirs;

* input folders and libraries: set once in PART 1 ;
* MS_wls macros: defined in PART 3 ;
* MS_fe_cr0 macros: defined in PART 3 ;
* MS_ppml macros: defined in PART 3 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.msfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values (falsification rows of table S2) */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if input(s, best32.) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    function cis(e, l, h, d) $ 120;
        length s $120;
        s = strip(sg(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 72 713) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
run;
options cmplib=work.msfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(12), part char(80), row char(160), col char(80), value char(120));
quit;

/* %add(order, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro add(o, part, row, col, val, ds=_one, wh=1);
    %local _n;
    data _addrow;
        set &ds;
        where &wh;
        length _x_exh $12 _x_part $80 _x_row $160 _x_col $80 _x_val $120;
        _x_ord = &o; _x_exh = "&EXH"; _x_part = "&part"; _x_row = "&row"; _x_col = "&col";
        _x_val = &val;
        keep _x_ord _x_exh _x_part _x_row _x_col _x_val;
    run;
    proc sql noprint; select count(*) into :_n trimmed from _addrow; quit;
    %if &_n ne 1 %then %do; %put ERROR: add &o selected &_n rows instead of one.; %abort cancel; %end;
    proc append base=RES force
        data=_addrow(rename=(_x_ord=ord _x_exh=exhibit _x_part=part _x_row=row _x_col=col _x_val=value));
    run;
%mend;

%macro ms_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MS_setup.sas ;

/* ---- computation ---- */
* from MS_s1cells.sas ;
/* MS_s1cells.sas - INCLUDE ONLY.  ASCII only.
   Time cell rate ratios behind table S1 panels 1 and 2 (and the rows of table S3 that summarise them).
   From the table program: common dataset XA; TABLE 3 and TABLE S1 PANEL 1 (%fe_cr0, five definitions);
   TABLE S1 PANEL 2 (%ppml_fe, five definitions).  From check program 25 part 2: abandoned plus menu ended
   calls without callback requests, log rate model and Poisson.
   Creates: XA; fA fB fAs fBs fW (log rate); pA pB pAs pBs pW (Poisson); fAM pAM (abandoned plus menu ended).
   Each has one row per level (rush_Mon midday late pre8) with rr lcl ucl n_clust. */

%let STABLE = 202510;
%let LEVELS = rush_Mon midday late pre8;

/* XA : day and time cells in the stable window, practices with 1000+ calls */
proc sql;
    create table _keepA as
    select practice from perm.cell_daytime
    where month >= "&STABLE." group by practice having sum(CBT001) >= 1000;
quit;
data XA;
    set perm.cell_daytime;
    where month >= "&STABLE.";
    if _n_ = 1 then do;
        declare hash k(dataset:'_keepA'); k.definekey('practice'); k.definedone();
    end;
    if k.check() ne 0 then delete;
    q = CBT001 - CBT002;
run;

%fe_cr0(data=XA, num=CBT004,               den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fA,  label=%str(A abandonment));
%fe_cr0(data=XA, num=CBT004+CBT005,        den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fB,  label=%str(B real time non-connection));
%fe_cr0(data=XA, num=CBT004,               den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fAs, label=%str(A* queue restricted abandonment));
%fe_cr0(data=XA, num=CBT004+CBT005,        den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fBs, label=%str(B* queue restricted non-connection));
%fe_cr0(data=XA, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fW,  label=%str(W total non-connection));

%ppml_fe(data=XA, num=CBT004,               den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pA,  label=%str(A abandonment));
%ppml_fe(data=XA, num=CBT004+CBT005,        den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pB,  label=%str(B real time non-connection));
%ppml_fe(data=XA, num=CBT004,               den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pAs, label=%str(A* queue restricted abandonment));
%ppml_fe(data=XA, num=CBT004+CBT005,        den=q,      grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pBs, label=%str(B* queue restricted non-connection));
%ppml_fe(data=XA, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pW,  label=%str(W total non-connection));

/* check program 25 part 2: abandoned + menu ended (callback requests not counted) */
%fe_cr0(data=XA, num=CBT002+CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=fAM, label=%str(A+M log rate WLS));
%ppml_fe(data=XA, num=CBT002+CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
         gid=catx('|', practice, month), cid=practice, out=pAM, label=%str(A+M Poisson));

/* all models stacked, one row per definition and level: defn in A B As Bs W AM, est in LR PO */
data S1RR;
    length defn $4 est $2;
    set fA(in=a1) fB(in=a2) fAs(in=a3) fBs(in=a4) fW(in=a5) fAM(in=a6)
        pA(in=b1) pB(in=b2) pAs(in=b3) pBs(in=b4) pW(in=b5) pAM(in=b6);
    if a1 or b1 then defn = 'A';  else if a2 or b2 then defn = 'B';  else if a3 or b3 then defn = 'As';
    else if a4 or b4 then defn = 'Bs'; else if a5 or b5 then defn = 'W'; else defn = 'AM';
    est = ifc(a1 or a2 or a3 or a4 or a5 or a6, 'LR', 'PO');
    keep defn est level rr lcl ucl n_clust;
run;
* end of MS_s1cells.sas ;
* from MS_link.sas ;
/* MS_link.sas - INCLUDE ONLY.  ASCII only.
   The survey link models of the table program: common dataset LK; TABLE 2 PANEL 1 (weighted R2 of the
   five definitions, both waves); TABLE 2 PANEL 2 (the three component models = manuscript table S2 rows across
   practices, opening hours, within practices and the falsification test).
   Creates: LK; T2R2 (tag A B As Bs W, r2_25 r2_26 n_25 n_26); T2P2 (model, var, coef, se, lo, hi, r2, n), with
   model in a25 a26 a26h fd fals. */

/* LK : the survey link; W recomputed from the three published components (as the table program) */
data LK;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
run;

/* TABLE 2 PANEL 1: one definition at a time */
%macro r2def(yr, tag, out);
    %local d v;
    data _s; set LK; where A_&tag ne . and ease_&yr ne .; run;
    %do d = 1 %to 5;
        %let v = %scan(A B As Bs W, &d);
        %wls(data=_s, y=ease_&yr, x=&v._&tag, w=n_eval_&yr, out=_o&d, tag=&v);
        data _o&d; set _o&d; where var ne 'Intercept'; run;
    %end;
    data &out; set _o1-_o5; run;
%mend;
%r2def(2025, w25, _p1a);
%r2def(2026, w26, _p1b);
proc sql;
    create table T2R2 as
    select a.tag length=4, a.r2 as r2_25, a.n as n_25, b.r2 as r2_26, b.n as n_26
    from _p1a a inner join _p1b b on a.tag = b.tag;
quit;

/* TABLE 2 PANEL 2: three components */
data _s25;  set LK; where A_w25  ne . and ease_2025 ne .; run;
data _s26;  set LK; where A_w26  ne . and ease_2026 ne .; run;
data _s26h; set LK; where Ah_w26 ne . and ease_2026 ne .; run;
%wls(data=_s25,  y=ease_2025, x=A_w25  cb_w25  menu_w25,  w=n_eval_2025, out=_m1, tag=a25);
%wls(data=_s26,  y=ease_2026, x=A_w26  cb_w26  menu_w26,  w=n_eval_2026, out=_m2, tag=a26);
%wls(data=_s26h, y=ease_2026, x=Ah_w26 cbh_w26 menuh_w26, w=n_eval_2026, out=_m3, tag=a26h);
data _chg;
    set LK;
    where n_months_w25 >= 2 and n_months_w26 >= 2 and ease_2025 ne . and ease_2026 ne .;
    dY    = ease_2026 - ease_2025;
    dA    = A_w26    - A_w25;
    dcb   = cb_w26   - cb_w25;
    dmenu = menu_w26 - menu_w25;
    wmin  = min(n_eval_2025, n_eval_2026);
    if ease_2024 ne . then dY_prev = ease_2025 - ease_2024;
run;
%wls(data=_chg, y=dY,      x=dA dcb dmenu, w=wmin, out=_m4, tag=fd);
%wls(data=_chg, y=dY_prev, x=dA dcb dmenu, w=wmin, out=_m5, tag=fals);
data T2P2;
    length model $8 comp $4;
    set _m1 _m2 _m3 _m4 _m5;
    model = tag;
    if      index(var, 'menu') then comp = 'menu';
    else if index(var, 'cb')   then comp = 'cb';
    else if index(var, 'A')    then comp = 'A';
    else comp = 'int';
    lo = coef - 1.96 * se; hi = coef + 1.96 * se;
    keep model comp var coef se lo hi r2 n;
run;
* end of MS_link.sas ;
* from MS_tamisc.sas ;
/* MS_tamisc.sas - INCLUDE ONLY.  ASCII only.
   Sections of the table program summarised in table S3, and check program 33 part 2b:
     TABLE 3 PANEL B (types of day, daily source files)                  -> BA BB (daytype rr lcl ucl)
     TABLE S4 PANEL 1 and 3 (= manuscript table S6: callback use)          -> C0 C1 (by callback use), CT1-CT3
                                                                             (callback intensity tertiles)
     TABLE S5 PANEL 1 and 2 (= manuscript table S7: shared postcode)       -> S5P1R (r_A r_W), S5P2R2 (r2)
     TABLE S7 (= manuscript table S9: ease by entry cohort)                -> S7 (ord change e2024 e2026)
     check program 33 part 2b (fig S3: balanced panel)                             -> S3M (month rush_share a_rush a_rest),
                                                                              S3S (n_bal)
   Needs LK (MS_link.sas) for the shared postcode and entry cohort sections. */

%let T1MONTH = 202606;

/* TABLE 3 PANEL B */
data XB;
    set perm.daily_rush;
    ymon = substr(Date, 1, 7);
run;
%fe_cr0(data=XB, num=CBT004,        den=CBT001, grp=daytype, ref=ordinary_Tuesday,
        levels=Wed_to_Fri ordinary_Monday postholiday_Tuesday,
        gid=catx('|', practice, ymon), cid=Date, out=bA, label=%str(A abandonment));
%fe_cr0(data=XB, num=CBT004+CBT005, den=CBT001, grp=daytype, ref=ordinary_Tuesday,
        levels=Wed_to_Fri ordinary_Monday postholiday_Tuesday,
        gid=catx('|', practice, ymon), cid=Date, out=bB, label=%str(B real time non-connection));

/* TABLE S4 (callback checks) */
proc sql;
    create table _evercd as
    select practice, (sum(CBT005) > 0) as ever_cb,
           sum(CBT005) / sum(CBT001)   as cb_int
    from perm.cell_daytime group by practice;
quit;
proc sql;
    create table _lsz as
    select practice_code as practice, max(list_size) as list_size
    from perm.practice_month where month = "&T1MONTH." group by practice_code;
quit;
proc sql;
    create table XC as
    select a.*, b.ever_cb, b.cb_int, c.list_size
    from perm.cell_daytime(where=(month >= "202510")) a
         inner join _evercd b on a.practice = b.practice
         left  join _lsz    c on a.practice = c.practice;
quit;
data _s0; set XC; where ever_cb = 0; run;
data _s1; set XC; where ever_cb = 1; run;
%fe_cr0(data=_s0, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
        gid=catx('|', practice, month), cid=practice, out=c0, label=%str(no callback));
%fe_cr0(data=_s1, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
        gid=catx('|', practice, month), cid=practice, out=c1, label=%str(callback));
proc sql;
    create table _cbi as select distinct practice, cb_int from XC where ever_cb = 1;
quit;
proc rank data=_cbi out=_cbi groups=3; var cb_int; ranks cbter; run;
proc sql;
    create table XC3 as
    select a.*, b.cbter from XC a inner join _cbi b on a.practice = b.practice;
quit;
%macro cbter(t, lab, out);
    data _sy; set XC3; where cbter = &t; run;
    %fe_cr0(data=_sy, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday,
            gid=catx('|', practice, month), cid=practice, out=&out, label=%str(&lab));
%mend;
%cbter(0, Lowest tertile, ct1); %cbter(1, Middle tertile, ct2); %cbter(2, Highest tertile, ct3);

/* TABLE S5 (practices sharing a postcode) */
data _site;
    set LK;
    where A_w26 ne . and ease_2026 ne . and postcode ne '';
    pc = upcase(compress(postcode));
run;
proc sql;
    create table _site2 as
    select a.*, b.nsite,
           a.ease_2026 - b.mY as y_dm, a.A_w26 - b.mA as A_dm, a.W_w26 - b.mW as W_dm,
           a.cb_w26 - b.mcb as cb_dm, a.menu_w26 - b.mmenu as menu_dm
    from _site a inner join
         (select pc, count(*) as nsite, mean(ease_2026) as mY, mean(A_w26) as mA,
                 mean(W_w26) as mW, mean(cb_w26) as mcb, mean(menu_w26) as mmenu
          from _site group by pc having count(*) >= 2) b
    on a.pc = b.pc;
    create table S5P1R as
    select count(*) as n_practices, count(distinct pc) as n_sites,
           sum(y_dm * A_dm) / sqrt(sum(y_dm * y_dm) * sum(A_dm * A_dm)) as r_A,
           sum(y_dm * W_dm) / sqrt(sum(y_dm * y_dm) * sum(W_dm * W_dm)) as r_W
    from _site2;
quit;
proc sql;
    create table _pc9 as
    select practice_code, max(postcode) as postcode,
           sum(cbt004_missed) / sum(cbt001_inbound)    as ab_rate,
           sum(cbt005_cb_requested) / sum(cbt001_inbound) as cb_int,
           mean(list_size)                             as list_size,
           1000 * mean(gp_fte_qualified) / mean(list_size)  as gp_per1000,
           1000 * mean(reception_fte)    / mean(list_size)  as rec_per1000,
           1000 * (sum(cbt001_inbound) / count(distinct month)) / mean(list_size) as calls_per1000
    from perm.practice_month
    where month >= "202510" and cbt_observed = 1 and cbt001_inbound > 0 and list_size > 0
    group by practice_code
    having sum(cbt001_inbound) > 0;
quit;
data _pc9;
    set _pc9;
    pc = upcase(compress(postcode));
    if pc ne '' and gp_per1000 ne . and rec_per1000 ne .;
run;
proc sql;
    create table _pc9d as
    select a.*,
           a.ab_rate      - b.m1 as z_y,
           a.cb_int       - b.m2 as z_cb,
           a.gp_per1000   - b.m3 as z_gp,
           a.list_size    - b.m4 as z_ls,
           a.rec_per1000  - b.m5 as z_rec,
           a.calls_per1000- b.m6 as z_cl
    from _pc9 a inner join
         (select pc, count(*) as nsite, mean(ab_rate) as m1, mean(cb_int) as m2,
                 mean(gp_per1000) as m3, mean(list_size) as m4,
                 mean(rec_per1000) as m5, mean(calls_per1000) as m6
          from _pc9 group by pc having count(*) >= 2) b
    on a.pc = b.pc;
quit;
proc means data=_pc9d noprint;
    var z_y z_cb z_gp z_ls z_rec z_cl;
    output out=_sd std = s_y s_cb s_gp s_ls s_rec s_cl;
run;
data _pc9s;
    if _n_ = 1 then set _sd;
    set _pc9d;
    sy = z_y / s_y; scb = z_cb / s_cb; sgp = z_gp / s_gp;
    sls = z_ls / s_ls; srec = z_rec / s_rec; scl = z_cl / s_cl;
    one = 1;
run;
%wls(data=_pc9s, y=sy, x=scb sgp sls srec scl, w=one, out=s5p2d, tag=within site);
data S5P2R2; set s5p2d; where var = 'Intercept'; keep r2 n; run;

/* TABLE S7 (ease by entry cohort) */
data _trend;
    set LK;
    where ease_2024 ne . and ease_2026 ne .;
    length cohort $44;
    if      first_month = ''        then do; cohort = 'Never in the collection';                  ord = 4; end;
    else if first_month <= '202412' then do; cohort = 'In the collection from October to December 2024'; ord = 1; end;
    else if first_month <= '202509' then do; cohort = 'Entered January to September 2025';        ord = 2; end;
    else                                 do; cohort = 'Entered October 2025 or later';           ord = 3; end;
run;
proc sql;
    create table S7 as
    select cohort, min(ord) as ord, count(*) as n,
           mean(ease_2024) as e2024, mean(ease_2025) as e2025, mean(ease_2026) as e2026,
           mean(ease_2026) - mean(ease_2024) as change
    from _trend group by cohort
    union all
    select 'All practices surveyed in all three years', 5, count(*),
           mean(ease_2024), mean(ease_2025), mean(ease_2026), mean(ease_2026) - mean(ease_2024)
    from _trend;
quit;

/* check program 33 part 2b: balanced panel (cbt_observed in all 21 months), weekday 06:00 to 18:30 cells */
proc sql;
    create table BAL as
    select practice_code from perm.practice_month where cbt_observed = 1
    group by practice_code having count(distinct month) = 21;
    create table S3M as
    select a.month,
           100 * sum(case when a.cell in ('rush_Mon', 'rush_TueFri') then a.CBT001 else 0 end) / sum(a.CBT001) as rush_share,
           100 * sum(case when a.cell in ('rush_Mon', 'rush_TueFri') then a.CBT004 else 0 end)
               / sum(case when a.cell in ('rush_Mon', 'rush_TueFri') then a.CBT001 else 0 end)          as a_rush,
           100 * sum(case when a.cell not in ('rush_Mon', 'rush_TueFri') then a.CBT004 else 0 end)
               / sum(case when a.cell not in ('rush_Mon', 'rush_TueFri') then a.CBT001 else 0 end)      as a_rest
    from perm.cell_daytime a inner join BAL b on a.practice = b.practice_code
    group by a.month order by a.month;
    create table S3S as
    select (select count(*) from BAL) as n_bal, count(*) as n_months from S3M;
quit;
* end of MS_tamisc.sas ;
%let C24P1 = 1; %let C24P2 = 1; %let C24P3 = 1; %let C24P4 = 1; %let C24P5 = 0;
* from MS_c24.sas ;
/* MS_c24.sas - INCLUDE ONLY.  ASCII only.
   Parts of check program 24 (identical in the min100 and unrestricted survey link runs; 24b = part 2 with more
   decimals).  Set before the include which parts to run (1 = run):
     C24P1  part 1, time cells with bank holidays and 22 December to 2 January removed (reads PERM.DT_ALL, slow)
            -> C24_P1 (model level rr_orig lcl_orig ucl_orig rr_xh lcl_xh ucl_xh inside in_rule)
     C24P2  part 2, practices sharing a postcode, site fixed effect, SE clustered by site (PROC SURVEYREG)
            -> C24_P2 (spec Parameter Estimate LowerCL UpperCL)
     C24P3  part 3, within-practice models: falsification test with 2025 levels, adjustment for 2024 ease and for
            the 2024 to 2025 change -> C24_P3 (tag var coef lo hi r2 n)
     C24P4  part 4, covariate-adjusted R2, 2026, bootstrap of the W - A difference (seed 20261005)
            -> C24_P4 (tag r2_adj increment), C24_P4B (r2_base), C24_P4D (diff p2_5 p97_5)
     C24P5  part 5, R2 of each definition and of W as (inbound - answered)/inbound -> C24_P5 (wave tag r2 n)
   Uses the library PERM as set by the caller. */

/* helper macros (as in check program 24) */
%macro mkXA(in, out);
    proc sql;
        create table _keep as
        select practice from &in
        where month >= "202510" group by practice having sum(CBT001) >= 1000;
    quit;
    data &out;
        set &in;
        where month >= "202510";
        if _n_ = 1 then do;
            declare hash k(dataset:'_keep'); k.definekey('practice'); k.definedone();
        end;
        if k.check() ne 0 then delete;
    run;
%mend;
%macro runfe(ds, s);
    %fe_cr0(data=&ds, num=CBT004,               den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
            gid=catx('|', practice, month), cid=practice, out=f&s.A, label=A);
    %fe_cr0(data=&ds, num=CBT004+CBT005,        den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
            gid=catx('|', practice, month), cid=practice, out=f&s.B, label=B);
    %fe_cr0(data=&ds, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday late pre8,
            gid=catx('|', practice, month), cid=practice, out=f&s.W, label=W);
    data f&s; length model $50 level $30; set f&s.A f&s.B f&s.W; run;
%mend;
%macro wold(months, tag);
    proc sql;
        create table _wo_&tag as
        select practice_code,
               100*(sum(cbt001_inbound)-sum(cbt003_answered))/sum(cbt001_inbound) as W_old_&tag
        from perm.practice_month
        where cbt_observed = 1 and cbt001_inbound > 0 and month in (&months)
        group by practice_code;
    quit;
    proc sort data=_wo_&tag; by practice_code; run;
%mend;
%macro glmr2(ds, x, tag, out, by=);
    proc glm data=&ds;
        %if %length(&by) %then %do; by &by; %end;
        class region_code;
        weight n_eval_2026;
        model ease_2026 = list_w26 calls_w26 imd region_code &x / solution;
        ods output FitStatistics=_fs;
    run; quit;
    data &out; length tag $24; set _fs; tag = "&tag"; keep &by tag RSquare; run;
%mend;
%macro r2four(yr, tag, out);
    %local d v;
    data _s; set LK24; where A_&tag ne . and ease_&yr ne .; run;
    %do d = 1 %to 6;
        %let v = %scan(A B As Bs W W_old, &d);
        %wls(data=_s, y=ease_&yr, x=&v._&tag, w=n_eval_&yr, out=_q&d, tag=&v);
    %end;
    data &out; length wave $4 tag $40; set _q1-_q6; where var ne 'Intercept'; wave = "&yr"; run;
%mend;

%macro _c24;

%if &C24P1 = 1 %then %do;
    data _bh;   /* holiday list = 06_daytime_db.sas (type of day analysis) */
        format d yymmdd10.;
        do d = '25DEC2024'd, '26DEC2024'd, '01JAN2025'd, '18APR2025'd, '21APR2025'd, '05MAY2025'd, '26MAY2025'd,
               '25AUG2025'd, '25DEC2025'd, '26DEC2025'd, '01JAN2026'd, '03APR2026'd, '06APR2026'd, '04MAY2026'd,
               '25MAY2026'd;
            output;
        end;
    run;
    data _cellsxh;
        if _n_ = 1 then do;
            if 0 then set _bh;
            declare hash h(dataset:'_bh'); h.definekey('d'); h.definedone();
        end;
        set perm.dt_all(keep=practice dt month_n dow band indicator value);
        where practice ne 'Unassigned' and 2 <= dow <= 6
          and indicator in ('CBT001','CBT002','CBT004','CBT005');
        if h.check(key:dt) = 0 then delete;
        if (month(dt) = 12 and day(dt) >= 22) or (month(dt) = 1 and day(dt) <= 2) then delete;
        length cell $12;
        if      band = '06:00-07:59' then cell = 'pre8';
        else if band = '08:00-09:59' then do;
            if dow = 2 then cell = 'rush_Mon'; else cell = 'rush_TueFri';
        end;
        else if band in ('10:00-11:59','12:00-13:59','14:00-15:59') then cell = 'midday';
        else if band in ('16:00-17:59','18:00-18:29') then cell = 'late';
        else delete;
        keep practice dt month_n cell indicator value;
    run;
    proc sql;
        create table cell_xh as
        select practice, month_n as month length=6, cell,
               sum(case when indicator='CBT001' then value else 0 end) as CBT001,
               sum(case when indicator='CBT002' then value else 0 end) as CBT002,
               sum(case when indicator='CBT004' then value else 0 end) as CBT004,
               sum(case when indicator='CBT005' then value else 0 end) as CBT005
        from _cellsxh group by practice, month_n, cell;
    quit;
    proc datasets lib=work nolist; delete _cellsxh; quit;
    %mkXA(perm.cell_daytime, XA0);
    %mkXA(cell_xh,           XA1);
    %runfe(XA0, 0);
    %runfe(XA1, 1);
    proc sql;
        create table C24_P1 as
        select a.model, a.level,
               a.rr as rr_orig, a.lcl as lcl_orig, a.ucl as ucl_orig,
               b.rr as rr_xh,   b.lcl as lcl_xh,   b.ucl as ucl_xh,
               (b.rr between a.lcl and a.ucl) as inside,
               (a.level ne 'pre8')      as in_rule
        from f0 a inner join f1 b on a.model = b.model and a.level = b.level
        order by a.model, a.level;
    quit;
%end;

%if &C24P2 = 1 or &C24P3 = 1 or &C24P4 = 1 or &C24P5 = 1 %then %do;
    /* old W formula (inbound - answered)/inbound, as 14_external_link.sas */
    %wold(%str('202501','202502','202503'), w25);
    %wold(%str('202601','202602','202603'), w26);
    proc sort data=perm.ext_link out=_el; by practice_code; run;
    data LK24;
        merge _el(in=e) _wo_w25 _wo_w26;
        by practice_code;
        if e;
        W_w25 = A_w25 + cb_w25 + menu_w25;
        W_w26 = A_w26 + cb_w26 + menu_w26;
    run;
%end;

%if &C24P2 = 1 %then %do;
    data _site;
        set LK24;
        where A_w26 ne . and ease_2026 ne . and postcode ne '';
        pc = upcase(compress(postcode));
    run;
    proc sql;
        create table _site2 as
        select a.*, b.nsite,
               a.ease_2026 - b.mY as y_dm, a.A_w26 - b.mA as A_dm,
               a.cb_w26 - b.mcb as cb_dm, a.menu_w26 - b.mmenu as menu_dm
        from _site a inner join
             (select pc, count(*) as nsite, mean(ease_2026) as mY, mean(A_w26) as mA,
                     mean(cb_w26) as mcb, mean(menu_w26) as mmenu
              from _site group by pc having count(*) >= 2) b
        on a.pc = b.pc;
    quit;
    data _site2; set _site2; one = 1; run;
    proc surveyreg data=_site2;
        class pc;
        model ease_2026 = A_w26 cb_w26 menu_w26 pc / solution clparm;
        cluster pc;
        ods output ParameterEstimates=_s2u;
    run;
    data C24_P2;
        length spec $30;
        set _s2u;
        where Parameter in ('A_w26', 'cb_w26', 'menu_w26');
        spec = 'site FE, unweighted';
        keep spec Parameter Estimate LowerCL UpperCL;
    run;
%end;

%if &C24P3 = 1 %then %do;
    data _chg;
        set LK24;
        where n_months_w25 >= 2 and n_months_w26 >= 2 and ease_2025 ne . and ease_2026 ne .;
        dY    = ease_2026 - ease_2025;
        dA    = A_w26    - A_w25;
        dcb   = cb_w26   - cb_w25;
        dmenu = menu_w26 - menu_w25;
        wmin  = min(n_eval_2025, n_eval_2026);
        wprev = min(n_eval_2024, n_eval_2025);
        if ease_2024 ne . then dY_prev = ease_2025 - ease_2024;
    run;
    %wls(data=_chg, y=dY_prev, x=dA dcb dmenu A_w25 cb_w25 menu_w25,   w=wprev, out=_c1, tag=%str(levels));
    %wls(data=_chg, y=dY,      x=dA dcb dmenu ease_2024,               w=wmin, out=_c2, tag=%str(ease2024));
    %wls(data=_chg, y=dY,      x=dA dcb dmenu dY_prev,                 w=wmin, out=_c3, tag=%str(dYprev));
    data C24_P3;
        length tag $40;
        set _c1 _c2 _c3;
        lo = coef - 1.96 * se; hi = coef + 1.96 * se;
        keep tag var coef se lo hi r2 n;
    run;
%end;

%if &C24P4 = 1 %then %do;
    data _r4;
        set LK24;
        where ease_2026 ne . and n_eval_2026 > 0 and A_w26 ne . and B_w26 ne . and As_w26 ne .
          and Bs_w26 ne . and W_w26 ne . and list_w26 ne . and calls_w26 ne . and imd ne .
          and region_code ne '';
    run;
    %glmr2(_r4, ,                       base, _g0);
    %glmr2(_r4, A_w26,                  A,    _g1);
    %glmr2(_r4, B_w26,                  B,    _g2);
    %glmr2(_r4, As_w26,                 As,   _g3);
    %glmr2(_r4, Bs_w26,                 Bs,   _g4);
    %glmr2(_r4, W_w26,                  W,    _g5);
    proc sql;
        create table C24_P4B as select RSquare as r2_base, (select count(*) from _r4) as n from _g0;
        create table C24_P4 as
        select a.tag, a.RSquare as r2_adj, a.RSquare - b.RSquare as increment
        from (select * from _g1 union all select * from _g2 union all select * from _g3
              union all select * from _g4 union all select * from _g5) a, _g0 b;
    quit;
    proc surveyselect data=_r4 out=_rb method=urs samprate=1 reps=2000 outhits seed=20261005 noprint;
    run;
    %glmr2(_rb, A_w26, A, _b1, by=Replicate);
    %glmr2(_rb, W_w26, W, _b5, by=Replicate);
    proc sql;
        create table _bd as
        select a.Replicate, b.RSquare - a.RSquare as d
        from _b1 a inner join _b5 b on a.Replicate = b.Replicate;
    quit;
    proc univariate data=_bd noprint;
        var d; output out=_bq pctlpts=2.5 97.5 pctlpre=p n=nrep;
    run;
    proc sql;
        create table C24_P4D as
        select q.p2_5, q.p97_5, w.r2_adj - a.r2_adj as diff
        from _bq q, C24_P4 w, C24_P4 a
        where w.tag = 'W' and a.tag = 'A';
    quit;
%end;

%if &C24P5 = 1 %then %do;
    %r2four(2025, w25, _f25);
    %r2four(2026, w26, _f26);
    data C24_P5; set _f25 _f26; keep wave tag r2 n; run;
%end;
%mend _c24;
%_c24;
* end of MS_c24.sas ;
%let C25P1 = 1; %let C25C74 = 0; %let C25P3 = 1; %let C25P4 = 1; %let C26P92 = 0;
* from MS_c25.sas ;
/* MS_c25.sas - INCLUDE ONLY.  ASCII only.
   Parts of check program 25, check program 25b, check program 25c and
   check program 26 (the four programs share the same first steps: LK sorted by practice, the
   durations files read into DUR, DURP and LKD).  Set before the include (1 = run):
     C25P1   check program 25 part 1c/1d (= 25b): R2 of A, W, L2 (answered after more than 2 min), L5 (more than 5 min) on
             the common sample, bootstrap of R2(W) - R2(L2) (seed 20261006)  -> C25_R2 (wave tag r2 n), C25_BQ
     C25C74  check program 25c 7-4: three component model with and without the waiting time share -> C25_74
     C25P3   check program 25 part 3: extended covariates (workforce, online consultation, GPAD appointments, age 65+),
             W - A increment difference with bootstrap (seed 20261006) -> C25_P3 (variant n d_W_A p2_5 p97_5)
     C25P4   check program 25 part 4b: R2(W) - R2(A) with networks resampled (seed 20261006) -> C25_P4 (wave p2_5 p97_5)
     C26P92  check program 26 part 9-2: covariate adjusted three component model, HC1 -> C26_92 (var coef lo hi r2 n)
   Uses the library PERM as set by the caller. */

%let SEED25  = 20261006;
%let NBOOT25 = 2000;

%macro readdur(mon, yr, tag);
    %local r rg;
    %do r = 1 %to 7;
        %let rg = %scan(Y56 Y58 Y59 Y60 Y61 Y62 Y63, &r);
        data _d;
            length practice $10 indicator $10 dur $12;
            infile "&CBTDIR.\Cloud Based Telephony By Durations - &mon. &yr._&rg..csv" dsd truncover firstobs=2 lrecl=2048;
            input dt : yymmdd10. region_code : $10. icb : $20. sub_icb : $20. pcn : $20. practice $ indicator $ dur $ value;
            if missing(value) then value = 0;
            if practice = 'Unassigned' then delete;   /* shared-account calls, as PERM.DT_ALL */
            keep practice indicator dur value;
        run;
        proc sql;
            create table _a as
            select practice,
                   sum(case when indicator='CBT001' then value else 0 end) as inb,
                   sum(case when indicator='CBT003' then value else 0 end) as ans,
                   sum(case when indicator='CBT003' and dur in ('121_180','181_240','241_300','>300') then value else 0 end) as ans120,
                   sum(case when indicator='CBT003' and dur = '>300' then value else 0 end) as ans300,
                   sum(case when indicator='CBT004' then value else 0 end) as mis,
                   sum(case when indicator='CBT004' and dur in ('121_180','181_240','241_300','>300') then value else 0 end) as mis120
            from _d group by practice;
        quit;
        data _a; length wave $3 mon $16; set _a; wave = "&tag"; mon = "&mon.&yr"; run;
        proc append base=DUR data=_a force; run;
    %end;
%mend;

%macro r2set(yr, tag);
    data _s&tag; set LKD;
        where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne . and W_&tag ne . and L2_&tag ne .
          and L5_&tag ne . and M2_&tag ne .;
        y = ease_&yr; w = n_eval_&yr; xA = A_&tag; xW = W_&tag; L2 = L2_&tag; L5 = L5_&tag; M2 = M2_&tag;
        keep practice_code pcl y w xA xW L2 L5 M2;
    run;
    %local d v;
    %do d = 1 %to 5;
        %let v = %scan(xA xW L2 L5 M2, &d);
        %wls(data=_s&tag, y=y, x=&v, w=w, out=_r&d, tag=&v);
    %end;
    data r2_&tag; length tag $40 wave $4; set _r1-_r5; wave = "&yr"; run;
%mend;
%macro r2boot(tag);
    proc surveyselect data=_s&tag out=_b&tag method=urs samprate=1 reps=&NBOOT25 outhits seed=&SEED25 noprint; run;
    %local m;
    %do m = 1 %to 4;
        proc reg data=_b&tag outest=_e&m(keep=Replicate _RSQ_) rsquare noprint;
            by Replicate; weight w;
            %if &m = 1 %then %do; model y = xA; %end;
            %if &m = 2 %then %do; model y = xW; %end;
            %if &m = 3 %then %do; model y = L2; %end;
            %if &m = 4 %then %do; model y = xW L2; %end;
        run; quit;
        data _e&m; set _e&m; rename _RSQ_ = r&m; run;
    %end;
    data _bd&tag; merge _e1 _e2 _e3 _e4; by Replicate;
        d_L2_A = r3 - r1; d_W_L2 = r2 - r3; inc_L2 = r4 - r2;
    run;
    proc univariate data=_bd&tag noprint;
        var d_L2_A d_W_L2 inc_L2;
        output out=_bq&tag pctlpts=2.5 97.5 pctlpre=LA_ WL_ IN_;
    run;
%mend;
%macro comp4(yr, tag);
    data _q&tag; set LKD; where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne . and L2_&tag ne .;
        y = ease_&yr; w = n_eval_&yr; xA = A_&tag; xcb = cb_&tag; xmenu = menu_&tag; L2 = L2_&tag; run;
    %wls(data=_q&tag, y=y, x=xA xcb xmenu,    w=w, out=_k1, tag=%str(&yr three));
    %wls(data=_q&tag, y=y, x=xA xcb xmenu L2, w=w, out=_k2, tag=%str(&yr plusL2));
    data k_&tag; length tag $40; set _k1 _k2; where var ne 'Intercept'; run;
%mend;
%macro rdgpad(file, wave, mon);
    data _g;
        length gp $10 a1-a12 $200 cnt 8;
        infile "&ROOT.\GPAD DB\&file" dsd truncover firstobs=2 lrecl=4096;
        input a1 $ gp $ a2 $ a3 $ a4 $ a5 $ a6 $ a7 $ a8 $ a9 $ a10 $ a11 $ cnt a12 $;
        keep gp cnt;
    run;
    proc sql; create table _gs as select gp as practice_code length=10, sum(cnt) as appts from _g group by gp; quit;
    data _gs; length wave $3 src $80 mon $6; set _gs; wave = "&wave"; src = "&file"; mon = "&mon"; run;
    proc append base=GPAD data=_gs force; run;
%mend;
%macro glmr2c(ds, x, tag, out, covs=, by=);
    proc glm data=&ds;
        %if %length(&by) %then %do; by &by; %end;
        class region_code;
        weight wgt;
        model y = &covs region_code &x;
        ods output FitStatistics=_fs;
    run; quit;
    data &out; length tag $24; set _fs; tag = "&tag"; keep &by tag RSquare; run;
%mend;
%macro covvar(vname, yr, tag, covs, where=1);
    data _c; set LKC;
        where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne . and B_&tag ne . and As_&tag ne . and Bs_&tag ne .
          and W_&tag ne . and list_&tag ne . and calls_&tag ne . and imd ne . and region_code ne ''
          and gp_&tag ne . and rec_&tag ne . and loc_&tag ne . and appt_&tag ne . and s65_&tag ne . and &where;
        y = ease_&yr; wgt = n_eval_&yr; A = A_&tag; B = B_&tag; As = As_&tag; Bs = Bs_&tag; W = W_&tag;
        lst = list_&tag; cls = calls_&tag; gp = gp_&tag; rec = rec_&tag; loc = loc_&tag; appt = appt_&tag; s65 = s65_&tag;
    run;
    %glmr2c(_c, ,   base, _g0, covs=&covs);
    %glmr2c(_c, A,  A,  _g1, covs=&covs);
    %glmr2c(_c, B,  B,  _g2, covs=&covs);
    %glmr2c(_c, As, As, _g3, covs=&covs);
    %glmr2c(_c, Bs, Bs, _g4, covs=&covs);
    %glmr2c(_c, W,  W,  _g5, covs=&covs);
    proc sql noprint; select count(*) into :_nc trimmed from _c; quit;
    proc sql;
        create table _inc as
        select "&vname" as variant length=40, &_nc as n, b.RSquare as r2_base, a.tag, a.RSquare - b.RSquare as increment
        from (select * from _g1 union all select * from _g2 union all select * from _g3 union all select * from _g4
              union all select * from _g5) a, _g0 b;
    quit;
    proc append base=P3INC data=_inc force; run;
    proc surveyselect data=_c out=_cb method=urs samprate=1 reps=&NBOOT25 outhits seed=&SEED25 noprint; run;
    %glmr2c(_cb, A, A, _cbA, covs=&covs, by=Replicate);
    %glmr2c(_cb, W, W, _cbW, covs=&covs, by=Replicate);
    data _cbd; merge _cbA(rename=(RSquare=rA)) _cbW(rename=(RSquare=rW)); by Replicate; d = rW - rA; run;
    proc univariate data=_cbd noprint; var d; output out=_cbq pctlpts=2.5 97.5 pctlpre=p; run;
    data _cbq; length variant $40; set _cbq; variant = "&vname"; run;
    proc append base=P3BOOT data=_cbq force; run;
%mend;
%macro pcnreg(yr, tag);
    data _p; set LK25; where ease_&yr ne . and n_eval_&yr > 0 and A_&tag ne .;
        y = ease_&yr; wgt = n_eval_&yr; A = A_&tag; cb = cb_&tag; menu = menu_&tag; W = W_&tag; run;
    proc sql; create table _pc as select distinct pcl from _p; quit;
    proc surveyselect data=_pc out=_pcb method=urs samprate=1 reps=&NBOOT25 outhits seed=&SEED25 noprint; run;
    proc sql; create table _pb as select b.Replicate, a.* from _pcb b inner join _p a on a.pcl = b.pcl order by b.Replicate; quit;
    proc reg data=_pb outest=_q1(keep=Replicate _RSQ_ rename=(_RSQ_=rA)) rsquare noprint; by Replicate; weight wgt; model y = A; run; quit;
    proc reg data=_pb outest=_q2(keep=Replicate _RSQ_ rename=(_RSQ_=rW)) rsquare noprint; by Replicate; weight wgt; model y = W; run; quit;
    data _qd; merge _q1 _q2; by Replicate; d = rW - rA; run;
    proc univariate data=_qd noprint; var d; output out=_qq&tag pctlpts=2.5 97.5 pctlpre=p; run;
    data _qq&tag; length wave $4; set _qq&tag; wave = "&yr"; run;
%mend;

%macro _c25;
/* LK: survey link, W as the sum of the three components; network cluster (as check program 25) */
data LK25;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
    length pcl $10;
    pcl = coalescec(pcn_code, practice_code);
run;
proc sort data=LK25; by practice_code; run;

%if &C25P1 = 1 or &C25C74 = 1 or &C25P3 = 1 %then %do;
    proc datasets lib=work nolist nowarn; delete DUR; quit;
    %readdur(January,  2025, w25); %readdur(February, 2025, w25); %readdur(March, 2025, w25);
    %readdur(January,  2026, w26); %readdur(February, 2026, w26); %readdur(March, 2026, w26);
    proc sql;
        create table DURP as
        select practice as practice_code length=10, wave,
               sum(inb) as inb, sum(ans) as ans, sum(ans120) as ans120, sum(ans300) as ans300, sum(mis120) as mis120
        from DUR group by practice, wave;
    quit;
    data DURP; set DURP;
        if ans > 0 then do; L2 = 100 * ans120 / ans; L5 = 100 * ans300 / ans; end;
        if inb > 0 then M2 = 100 * mis120 / inb;
    run;
    proc sql;
        create table LKD as
        select a.*, b.L2 as L2_w25, b.L5 as L5_w25, b.M2 as M2_w25, c.L2 as L2_w26, c.L5 as L5_w26, c.M2 as M2_w26
        from LK25 a left join DURP(where=(wave='w25')) b on a.practice_code = b.practice_code
                  left join DURP(where=(wave='w26')) c on a.practice_code = c.practice_code;
    quit;
%end;

%if &C25P1 = 1 %then %do;
    %r2set(2025, w25);
    %r2set(2026, w26);
    data C25_R2; set r2_w25 r2_w26; where var ne 'Intercept'; keep wave tag coef r2 n; run;
    %r2boot(w25);
    %r2boot(w26);
    data C25_BQ; length wave $4; set _bqw25(in=a) _bqw26; wave = ifc(a, '2025', '2026'); run;
%end;

%if &C25C74 = 1 %then %do;
    %comp4(2025, w25);
    %comp4(2026, w26);
    data C25_74; set k_w25 k_w26; lo = coef - 1.96 * se; hi = coef + 1.96 * se; keep tag var coef se lo hi r2 n; run;
%end;

%if &C25P3 = 1 %then %do;
    proc datasets lib=work nolist nowarn; delete GPAD P3INC P3BOOT; quit;
    %rdgpad(Practice_Level_Crosstab_Jan_25.csv, w25, 202501);
    %rdgpad(Practice_Level_Crosstab_Feb_25.csv, w25, 202502);
    %rdgpad(Practice_Level_Crosstab_Mar_25.csv, w25, 202503);
    %rdgpad(Practice_Level_Crosstab_Jan_26.csv, w26, 202601);
    %rdgpad(Practice_Level_Crosstab_Feb_26.csv, w26, 202602);
    %rdgpad(Practice_Level_Crosstab_London_East_South_Mar_26.csv, w26, 202603);
    %rdgpad(Practice_Level_Crosstab_Midlands_North_Mar_26.csv, w26, 202603);
    proc sql; create table GPADW as select practice_code, wave, sum(appts) / count(distinct mon) as appts_month from GPAD group by practice_code, wave; quit;
    proc sql;
        create table COVW as
        select practice_code,
               case when month in ('202501','202502','202503') then 'w25' else 'w26' end as wave length=3,
               mean(list_size) as lsz, mean(gp_fte_qualified) as gpfte, mean(reception_fte) as recfte,
               mean(oc_rate_per_1000) as ocr, mean(share_65plus) as s65
        from perm.practice_month
        where month in ('202501','202502','202503','202601','202602','202603')
        group by practice_code, calculated wave;
        create table COV as
        select a.*, 1000 * a.gpfte / a.lsz as gp1000, 1000 * a.recfte / a.lsz as rec1000, log(1 + a.ocr) as loc,
               1000 * b.appts_month / a.lsz as appt1000
        from COVW a left join GPADW b on a.practice_code = b.practice_code and a.wave = b.wave
        where a.lsz > 0;
    quit;
    proc sql;
        create table LKC as
        select l.*, c5.gp1000 as gp_w25, c5.rec1000 as rec_w25, c5.loc as loc_w25, c5.appt1000 as appt_w25, c5.s65 as s65_w25,
                    c6.gp1000 as gp_w26, c6.rec1000 as rec_w26, c6.loc as loc_w26, c6.appt1000 as appt_w26, c6.s65 as s65_w26,
               (l.ease_2025 ne . and l.A_w25 ne .) as in25
        from LKD l left join COV(where=(wave='w25')) c5 on l.practice_code = c5.practice_code
                   left join COV(where=(wave='w26')) c6 on l.practice_code = c6.practice_code;
    quit;
    %covvar(2026 full,                 2026, w26, %str(lst cls imd gp rec loc appt s65));
    %covvar(2026 without calls,        2026, w26, %str(lst imd gp rec loc appt s65));
    %covvar(2025 full,                 2025, w25, %str(lst cls imd gp rec loc appt s65));
    proc sql;
        create table _p3d as
        select a.variant, a.n, max(case when a.tag='W' then a.increment end) - max(case when a.tag='A' then a.increment end) as d_W_A
        from P3INC a group by a.variant, a.n;
        create table C25_P3 as select a.*, b.p2_5, b.p97_5 from _p3d a inner join P3BOOT b on a.variant = b.variant;
    quit;
%end;

%if &C25P4 = 1 %then %do;
    %pcnreg(2025, w25);
    %pcnreg(2026, w26);
    data C25_P4; set _qqw25 _qqw26; run;
%end;

%if &C26P92 = 1 %then %do;
    proc sql noprint;
        select distinct region_code into :REGS separated by ' ' from LK25 where region_code ne '' order by region_code;
    quit;
    data _r92;
        set LK25;
        where ease_2026 ne . and n_eval_2026 > 0 and A_w26 ne . and B_w26 ne . and As_w26 ne .
          and Bs_w26 ne . and W_w26 ne . and list_w26 ne . and calls_w26 ne . and imd ne .
          and region_code ne '';
        array rg{7} rg1-rg7;
        do _i = 1 to 7; rg{_i} = (region_code = scan("&REGS", _i, ' ')); end;
    run;
    %wls(data=_r92, y=ease_2026, x=A_w26 cb_w26 menu_w26 list_w26 calls_w26 imd rg2 rg3 rg4 rg5 rg6 rg7, w=n_eval_2026, out=_q92, tag=%str(adjusted HC1 2026));
    data C26_92; set _q92; lo = coef - 1.96 * se; hi = coef + 1.96 * se; keep var coef se lo hi r2 n; run;
%end;
%mend _c25;
%_c25;
* end of MS_c25.sas ;
* from MS_c27.sas ;
/* MS_c27.sas - INCLUDE ONLY.  ASCII only.
   check program 27 (it reads no survey data, so the library makes no difference):
   time cell rate ratios and the most v least deprived decile ratio (bootstrap, seed 20260901) by period:
   STAB = October 2025 to June 2026, FULL = October 2024 to June 2026, PRE = October 2024 to September 2025.
   The macro %win is renamed %win27.  Creates N27 (win practices months), RR27 (win model level rr lcl ucl),
   DEP27 (win measure pt lcl ucl). */
%let LEVELS = rush_Mon midday late pre8;

%macro win27(tag, lo, hi);
    /* time cells: practices with 1000+ weekday calls in the period */
    proc sql;
        create table _keep&tag as
        select practice from perm.cell_daytime
        where "&lo" <= month <= "&hi" group by practice having sum(CBT001) >= 1000;
    quit;
    data X&tag;
        set perm.cell_daytime;
        where "&lo" <= month <= "&hi";
        if _n_ = 1 then do;
            declare hash k(dataset:"_keep&tag"); k.definekey('practice'); k.definedone();
        end;
        if k.check() ne 0 then delete;
    run;
    proc sql;
        create table n_&tag as
        select "&tag" as win length=4, count(distinct practice) as practices,
               count(distinct month) as months, sum(CBT001) / 1e6 as calls_m format=10.1
        from X&tag;
    quit;
    %fe_cr0(data=X&tag, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
            gid=catx('|', practice, month), cid=practice, out=fA_&tag, label=%str(A abandonment &tag));
    %fe_cr0(data=X&tag, num=CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
            gid=catx('|', practice, month), cid=practice, out=fB_&tag, label=%str(B real time &tag));
    %fe_cr0(data=X&tag, num=CBT002+CBT004+CBT005, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
            gid=catx('|', practice, month), cid=practice, out=fW_&tag, label=%str(W total &tag));
    data rr_&tag;
        length win $4;
        set fA_&tag fB_&tag fW_&tag;
        win = "&tag";
    run;

    /* deprivation: most v least deprived decile, means of practice rates (analysis program 12 rules) */
    proc sql;
        create table ps_&tag as
        select a.practice,
               sum(a.CBT001) as inb, sum(a.CBT004) as ab, sum(a.CBT005) as cb,
               sum(case when a.cell = 'rush_Mon' then a.CBT001 else 0 end) as mi,
               sum(case when a.cell = 'rush_Mon' then a.CBT004 else 0 end) as ma,
               sum(case when a.cell = 'rush_Mon' then a.CBT005 else 0 end) as mc,
               max(b.pw_imd_decile_1poorest) as dec
        from perm.cell_daytime a left join perm.practice_ref b on a.practice = b.practice_code
        where "&lo" <= a.month <= "&hi"
        group by a.practice;
    quit;
    data _eq&tag;
        set ps_&tag;
        where inb >= 1000 and mi > 0 and dec in (1, 10);
        A = 100 * ab / inb; B = 100 * (ab + cb) / inb;
        monA = 100 * ma / mi; monB = 100 * (ma + mc) / mi;
        keep dec A B monA monB;
    run;
    data _bt&tag(keep=rA rB rmA rmB);
        array a1{2000} _temporary_; array b1{2000} _temporary_;
        array m1{2000} _temporary_; array k1{2000} _temporary_;
        array a0{2000} _temporary_; array b0{2000} _temporary_;
        array m0{2000} _temporary_; array k0{2000} _temporary_;
        retain n1 n0 0;
        call streaminit(20260901);
        do until (eof);
            set _eq&tag end=eof;
            if dec = 1 then do; n1 + 1; a1{n1} = A; b1{n1} = B; m1{n1} = monA; k1{n1} = monB; end;
            else do;            n0 + 1; a0{n0} = A; b0{n0} = B; m0{n0} = monA; k0{n0} = monB; end;
        end;
        do rep = 1 to 2000;
            sa1 = 0; sb1 = 0; sm1 = 0; sk1 = 0;
            do i = 1 to n1; j = rand('integer', 1, n1); sa1 + a1{j}; sb1 + b1{j}; sm1 + m1{j}; sk1 + k1{j}; end;
            sa0 = 0; sb0 = 0; sm0 = 0; sk0 = 0;
            do i = 1 to n0; j = rand('integer', 1, n0); sa0 + a0{j}; sb0 + b0{j}; sm0 + m0{j}; sk0 + k0{j}; end;
            rA = (sa1/n1)/(sa0/n0); rB = (sb1/n1)/(sb0/n0); rmA = (sm1/n1)/(sm0/n0); rmB = (sk1/n1)/(sk0/n0);
            output;
        end;
        stop;
    run;
    proc univariate data=_bt&tag noprint;
        var rA rB rmA rmB;
        output out=_ci&tag pctlpts=2.5 97.5 pctlpre=rA_ rB_ rmA_ rmB_;
    run;
    proc sql;
        create table _pt&tag as
        select mean(case when dec = 1 then A end) / mean(case when dec = 10 then A end) as pt_A,
               mean(case when dec = 1 then B end) / mean(case when dec = 10 then B end) as pt_B,
               mean(case when dec = 1 then monA end) / mean(case when dec = 10 then monA end) as pt_mA,
               mean(case when dec = 1 then monB end) / mean(case when dec = 10 then monB end) as pt_mB,
               sum(dec = 1) as n1, sum(dec = 10) as n10
        from _eq&tag;
    quit;
    data dep_&tag;
        length win $4 measure $12;
        merge _pt&tag _ci&tag;
        win = "&tag";
        measure = 'A';        pt = pt_A;  lcl = rA_2_5;  ucl = rA_97_5;  output;
        measure = 'B';        pt = pt_B;  lcl = rB_2_5;  ucl = rB_97_5;  output;
        measure = 'Monday A'; pt = pt_mA; lcl = rmA_2_5; ucl = rmA_97_5; output;
        measure = 'Monday B'; pt = pt_mB; lcl = rmB_2_5; ucl = rmB_97_5; output;
        keep win measure pt lcl ucl n1 n10;
    run;
%mend;

%win27(STAB, 202510, 202606);
%win27(FULL, 202410, 202606);
%win27(PRE, 202410, 202509);

data N27; set n_STAB n_FULL n_PRE; run;
data RR27; set rr_STAB rr_FULL rr_PRE; run;
data DEP27; set dep_STAB dep_FULL dep_PRE; run;
* end of MS_c27.sas ;
* from MS_c14.sas ;
/* MS_c14.sas - INCLUDE ONLY.  ASCII only.
   check program 14 = analysis program 03: variance components of the
   practice month log abandonment rate (district, network, practice, months within a practice), unweighted (model A)
   and weighted by calls (model B), PROC HPMIXED.  The network code comes from the unrestricted survey link
   (PERMO.EXT_LINK = SAS_OUT), as in the original run.  Creates VPC_A and VPC_B (CovParm Subject Estimate vpc_pct). */
proc sql;
    create table _vc as
    select a.practice_code, a.month, a.region_code, a.lad_code,
           coalesce(b.pcn_code, cats('NOPCN_', a.practice_code)) as pcn_code length=20,
           log(a.cbt004_missed / a.cbt001_inbound) as y,
           a.cbt001_inbound as calls
    from perm.practice_month a left join permo.ext_link b
      on a.practice_code = b.practice_code
    where a.cbt_observed = 1 and a.cbt004_missed > 0 and a.cbt001_inbound > 0
      and a.lad_code ne '' and a.region_code ne '';
quit;
proc sql noprint; select mean(calls) into :mcalls from _vc; quit;
data _vc; set _vc; wn = calls / &mcalls; run;     /* weight, mean 1 */

/* Model A: unweighted */
proc hpmixed data=_vc;
    class month region_code lad_code pcn_code practice_code;
    model y = month region_code;
    random intercept / subject=lad_code;
    random intercept / subject=pcn_code;
    random intercept / subject=practice_code;
    ods output CovParms = cp_A;
run;

/* Model B: call weighted */
proc hpmixed data=_vc;
    class month region_code lad_code pcn_code practice_code;
    model y = month region_code;
    random intercept / subject=lad_code;
    random intercept / subject=pcn_code;
    random intercept / subject=practice_code;
    weight wn;
    ods output CovParms = cp_B;
run;

/* variance partition coefficients */
%macro vpc(ds=, tag=);
%if %sysfunc(exist(&ds)) %then %do;
    proc sql;
        create table vpc_&tag as
        select CovParm, Subject, Estimate,
               100 * Estimate / (select sum(Estimate) from &ds) as vpc_pct format=8.1
        from &ds;
    quit;
%end;
%mend;
%vpc(ds=cp_A, tag=A);
%vpc(ds=cp_B, tag=B);
* end of MS_c14.sas ;
* from MS_c15.sas ;
/* MS_c15.sas - INCLUDE ONLY.  ASCII only.
   check program 15 = analysis program 04 (reads no survey data): slope and relative
   indices of inequality across the ten patient weighted deprivation deciles, bootstrap within deciles (2000
   replicates, seed 20260925).  Creates SII_PT (measure SII RII RIIr) and SII_CI (one row: sii_A_lo ... riir_C_hi). */
/* 0. which column holds the practice code? */
%global PKEY;
%let PKEY = ;
%macro _pkey;
    %local dsid;
    %let dsid = %sysfunc(open(perm.practice_summary));
    %if %sysfunc(varnum(&dsid, practice)) > 0 %then %let PKEY = practice;
    %else %if %sysfunc(varnum(&dsid, practice_code)) > 0 %then %let PKEY = practice_code;
    %let dsid = %sysfunc(close(&dsid));
%mend; %_pkey;
%if %length(&PKEY) = 0 %then %do;
    %put ERROR: neither PRACTICE nor PRACTICE_CODE found in perm.practice_summary.;
    %abort cancel;
%end;

/* 1. practice level rates + list size */
proc sql;
    create table _ls as
    select practice_code, mean(list_size) as list_size
    from perm.practice_month
    where cbt_observed = 1 and list_size > 0
    group by practice_code;

    create table _s as
    select a.&PKEY as practice_code length=10,
           a.pw_imd_decile_1poorest as decile,
           100*a.abandoned_stablewin / a.inbound_stablewin                               as A,
           100*(a.abandoned_stablewin + a.callback_req_stablewin) / a.inbound_stablewin  as B,
           100*(a.abandoned_stablewin + a.callback_req_stablewin + a.menu_stablewin)
                / a.inbound_stablewin                                                    as C,
           coalesce(b.list_size, .) as list_size
    from perm.practice_summary a left join _ls b on a.&PKEY = b.practice_code
    where a.inbound_stablewin >= 1000 and a.pw_imd_decile_1poorest is not missing;
quit;
proc sql noprint;
    select count(*), nmiss(list_size) into :nprac, :nmiss_ls from _s;
quit;

/* 2. decile table: unweighted mean of practice rates (as fig S6A) */
proc sql;
    create table _dec as
    select decile,
           count(*)                          as n_prac,
           sum(list_size)                    as pop,
           mean(A) as mA, mean(B) as mB, mean(C) as mC
    from _s group by decile order by decile;
quit;

/* ridit score: cumulative population share, decile 1 (most deprived) first,
   x = midpoint of the decile's own segment. If list_size is unusable,
   fall back to the practice count. */
proc sql noprint;
    select sum(pop), sum(n_prac), nmiss(pop) into :sumpop, :sumn, :npopmiss from _dec;
quit;
%let WVAR = pop;
%if &npopmiss > 0 or &sumpop <= 0 %then %do;
    %let WVAR = n_prac;
    %put WARNING: list_size unusable - weighting the ridit by practice count instead.;
%end;
proc sql noprint; select sum(&WVAR) into :TOTW from _dec; quit;

data _dec;
    set _dec;
    retain _cum 0;
    share = &WVAR / &TOTW;
    x     = _cum + share/2;        /* 0 = most deprived end */
    _cum + share;
run;


/* 3. SII / RII point estimates */
/* weighted simple linear regression of the decile mean on x, by hand:
     b = Sw(x-xbar)(y-ybar) / Sw(x-xbar)^2 ,  a = ybar - b*xbar
   SII  = fit(0) - fit(1) = -b            (positive = worse in most deprived)
   RII  = SII / weighted mean             (OHID definition)
   RIIr = fit(0) / fit(1)                 (ratio definition, comparable with
                                           the decile ratio in the paper)   */
%macro sii(yv=, tag=, out=);
    proc sql noprint;
        select sum(&WVAR.*x)/sum(&WVAR.), sum(&WVAR.*&yv)/sum(&WVAR.)
          into :xb trimmed, :yb trimmed from _dec;
    quit;
    proc sql noprint;
        select sum(&WVAR.*(x-(&xb))*(&yv-(&yb)))
             / sum(&WVAR.*(x-(&xb))*(x-(&xb)))
          into :b trimmed from _dec;
    quit;
    data &out;
        length measure $4;
        measure = "&tag";
        b    = (&b);  a = (&yb) - (&b) * (&xb);
        fit0 = a;  fit1 = a + b;
        SII  = fit0 - fit1;
        RII  = SII / (&yb);
        RIIr = fit0 / fit1;
        wmean = (&yb);
        keep measure wmean fit0 fit1 SII RII RIIr;
    run;
%mend;
%sii(yv=mA, tag=A, out=_pA);
%sii(yv=mB, tag=B, out=_pB);
%sii(yv=mC, tag=C, out=_pC);
data _pt; set _pA _pB _pC; run;


/* 4. bootstrap: resample practices within decile, 2000 replicates */
/* The ridit x and the decile weights are held at their observed values
   (the population structure is not resampled); only the decile means are
   recomputed from the resampled practices. Fixed seed. */
proc sql noprint;
    select max(n_prac) into :maxn from _dec;
quit;

proc sort data=_s out=_ss; by decile; run;

%macro _bs(M=, sfx=);
    yb&sfx = 0; do d = 1 to 10; yb&sfx + WD{d}*&M{d}; end; yb&sfx = yb&sfx / tw;
    sxy&sfx = 0; do d = 1 to 10; sxy&sfx + WD{d}*(XD{d}-xb)*(&M{d}-yb&sfx); end;
    b&sfx  = sxy&sfx / sxx;
    a&sfx  = yb&sfx - b&sfx*xb;
    sii_&sfx  = -b&sfx;
    rii_&sfx  = sii_&sfx / yb&sfx;
    riir_&sfx = a&sfx / (a&sfx + b&sfx);
%mend;

data _boot(keep=rep sii_A rii_A riir_A sii_B rii_B riir_B sii_C rii_C riir_C);
    array RA{&maxn, 10} _temporary_;
    array RB{&maxn, 10} _temporary_;
    array RC{&maxn, 10} _temporary_;
    array ND{10} _temporary_;
    array WD{10} _temporary_;
    array XD{10} _temporary_;
    array MA{10} _temporary_;
    array MB{10} _temporary_;
    array MC{10} _temporary_;
    do i = 1 to 10; ND{i} = 0; end;
    /* decile weights and ridit scores */
    do until (ed);
        set _dec(keep=decile &WVAR x rename=(decile=_d &WVAR=_w x=_x)) end=ed;
        WD{_d} = _w; XD{_d} = _x;
    end;
    /* practice level rates, stacked by decile */
    do until (eof);
        set _ss end=eof;
        ND{decile} + 1;
        RA{ND{decile}, decile} = A;
        RB{ND{decile}, decile} = B;
        RC{ND{decile}, decile} = C;
    end;
    call streaminit(20260925);
    tw = 0; xb = 0;
    do d = 1 to 10; tw + WD{d}; xb + WD{d}*XD{d}; end;
    xb = xb / tw;
    sxx = 0; do d = 1 to 10; sxx + WD{d}*(XD{d}-xb)**2; end;
    do rep = 1 to 2000;
        do d = 1 to 10;
            sa = 0; sb = 0; sc = 0;
            do k = 1 to ND{d};
                j = ceil(rand('uniform') * ND{d});
                sa + RA{j, d}; sb + RB{j, d}; sc + RC{j, d};
            end;
            MA{d} = sa / ND{d}; MB{d} = sb / ND{d}; MC{d} = sc / ND{d};
        end;
        %_bs(M=MA, sfx=A); %_bs(M=MB, sfx=B); %_bs(M=MC, sfx=C);
        output;
    end;
run;

proc univariate data=_boot noprint;
    var sii_A rii_A riir_A sii_B rii_B riir_B sii_C rii_C riir_C;
    output out=_ci pctlpts=2.5 97.5
           pctlpre = sii_A_ rii_A_ riir_A_ sii_B_ rii_B_ riir_B_ sii_C_ rii_C_ riir_C_
           pctlname= lo hi;
run;
data SII_PT; set _pt; run;
data SII_CI; set _ci; run;
* end of MS_c15.sas ;
* from MS_c23c.sas ;
/* MS_c23c.sas - INCLUDE ONLY.  ASCII only.
   check program 23 part C (= analysis program 09 part C), 2025 wave, run on the UNRESTRICTED survey link
   (PERMO.EXT_LINK = SAS_OUT, all 3071 linked practices including the one with fewer than 100 inbound calls in
   January to March 2025), as the authors ran it from the unrestricted survey link run.  Weighted R2 of abandonment with a
   percentile interval from 2000 practice resamples (seed 20261002).  Creates C23C (R2_A n) and C23C_CI (A_2_5 A_97_5). */

data _r2025;
    set permo.ext_link;
    where A_w25 ne . and ease_2025 ne . and n_eval_2025 > 0;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    keep practice_code ease_2025 n_eval_2025 A_w25 B_w25 As_w25 Bs_w25 W_w25;
run;
proc surveyselect data=_r2025 out=_rb2025 method=urs samprate=1 reps=2000
                  seed=20261002 outhits noprint;
run;
data _rb2025; set _r2025(in=o) _rb2025; if o then replicate = 0; run;
proc sql;
    create table _q23 as
    select replicate,
           ( sum(n_eval_2025 * A_w25 * ease_2025) / sum(n_eval_2025)
             - (sum(n_eval_2025 * A_w25) / sum(n_eval_2025)) * (sum(n_eval_2025 * ease_2025) / sum(n_eval_2025)) ) ** 2
           / ( ( sum(n_eval_2025 * A_w25 ** 2) / sum(n_eval_2025) - (sum(n_eval_2025 * A_w25) / sum(n_eval_2025)) ** 2 )
             * ( sum(n_eval_2025 * ease_2025 ** 2) / sum(n_eval_2025) - (sum(n_eval_2025 * ease_2025) / sum(n_eval_2025)) ** 2 ) )
           as R2_A,
           count(*) as n
    from _rb2025 where A_w25 ne .
    group by replicate;
quit;
data C23C; set _q23; where replicate = 0; keep R2_A n; run;
proc univariate data=_q23(where=(replicate > 0)) noprint;
    var R2_A;
    output out=C23C_CI pctlpts=2.5 97.5 pctlpre=A_;
run;
* end of MS_c23c.sas ;
* from MS_c3132.sas ;
/* MS_c3132.sas - INCLUDE ONLY.  ASCII only.
   check program 31 parts 1 and 2 and check program 32 parts 1 and 3.  The two
   programs share their first steps (survey values, practice level rates for a list of months with at least 100
   inbound calls, waiting time from the durations files, analysis sets, R2 and bootstrap macros, seed 20261021);
   the macros are renamed here (win31, readdur31, aset31, r2_31, boot31) only to avoid clashing with other modules.
   Creates, for each analysis set: R31_<set> (measure r2 n) and BQ31_<set> (WA_2_5 WA_97_5 LA_2_5 LA_97_5), sets
     Q25c Q26c (January to March, common with October to March)  S25c S26c (October to March)   [check program 31 part 1]
     M25 M26 (January to March without |dev| > 5%), Q25 (count of |dev| > 5%: C31_DEV)           [check program 31 part 2]
     Q25j Q26j A25c A26c (January to April, common with January to March)                          [check program 32 part 1]
     R25 R26 (at least the median number of respondents)                                           [check program 32 part 3]
   Uses the library PERM as set by the caller. */

%let SEED31  = 20261021;
%let NBOOT31 = 2000;

data SV;
    set perm.ext_link;
    keep practice_code ease_2025 n_eval_2025 ease_2026 n_eval_2026 inb_w25 inb_w26 A_w25 A_w26;
run;
proc sort data=SV; by practice_code; run;

%macro win31(months, tag);
    proc sql;
        create table w_&tag as
        select practice_code,
               sum(cbt001_inbound) as inb_&tag,
               100*sum(cbt004_missed)/sum(cbt001_inbound)                                           as A_&tag,
               100*(sum(cbt004_missed)+sum(cbt005_cb_requested))/sum(cbt001_inbound)                 as B_&tag,
               100*sum(cbt004_missed)/(sum(cbt001_inbound)-sum(cbt002_ivr_ended))                    as As_&tag,
               100*(sum(cbt004_missed)+sum(cbt005_cb_requested))/(sum(cbt001_inbound)-sum(cbt002_ivr_ended)) as Bs_&tag,
               100*(sum(cbt004_missed)+sum(cbt005_cb_requested)+sum(cbt002_ivr_ended))/sum(cbt001_inbound)  as W_&tag,
               (sum(cbt002_ivr_ended)+sum(cbt003_answered)+sum(cbt004_missed)+sum(cbt005_cb_requested))
                   / sum(cbt001_inbound) - 1                                                          as dev_&tag
        from perm.practice_month
        where cbt_observed = 1 and cbt001_inbound > 0 and month in (&months)
        group by practice_code
        having sum(cbt001_inbound) >= 100;
    quit;
    proc sort data=w_&tag; by practice_code; run;
%mend;
%win31(%str('202501','202502','202503'), q25);
%win31(%str('202601','202602','202603'), q26);
%win31(%str('202410','202411','202412','202501','202502','202503'), s25);
%win31(%str('202510','202511','202512','202601','202602','202603'), s26);
%win31(%str('202501','202502','202503','202504'), a25);
%win31(%str('202601','202602','202603','202604'), a26);

%macro readdur31(mon, yr, tag);
    %local r rg f;
    %do r = 1 %to 7;
        %let rg = %scan(Y56 Y58 Y59 Y60 Y61 Y62 Y63, &r);
        %let f = &CBTDIR.\Cloud Based Telephony By Durations - &mon. &yr._&rg..csv;
        %if %sysfunc(fileexist(&f)) = 0 %then %do; %put ERROR: durations file missing (&mon &yr &rg); %abort cancel; %end;
        %else %do;
        data _d;
            length practice $10 indicator $10 dur $12;
            infile "&f" dsd truncover firstobs=2 lrecl=2048;
            input dt : yymmdd10. region_code : $10. icb : $20. sub_icb : $20. pcn : $20. practice $ indicator $ dur $ value;
            if missing(value) then value = 0;
            if practice = 'Unassigned' then delete;
            keep practice indicator dur value;
        run;
        proc sql;
            create table _a as select practice,
                   sum(case when indicator='CBT003' then value else 0 end) as ans,
                   sum(case when indicator='CBT003' and dur in ('121_180','181_240','241_300','>300') then value else 0 end) as ans120
            from _d group by practice;
        quit;
        data _a; length wave $3; set _a; wave = "&tag"; run;
        proc append base=DUR31 data=_a force; run;
        %end;
    %end;
%mend;
proc datasets lib=work nolist nowarn; delete DUR31; quit;
%readdur31(January, 2025, q25); %readdur31(February, 2025, q25); %readdur31(March, 2025, q25);
%readdur31(January, 2026, q26); %readdur31(February, 2026, q26); %readdur31(March, 2026, q26);
%readdur31(October, 2024, s25); %readdur31(November, 2024, s25); %readdur31(December, 2024, s25);
%readdur31(January, 2025, s25); %readdur31(February, 2025, s25); %readdur31(March, 2025, s25);
%readdur31(October, 2025, s26); %readdur31(November, 2025, s26); %readdur31(December, 2025, s26);
%readdur31(January, 2026, s26); %readdur31(February, 2026, s26); %readdur31(March, 2026, s26);
%readdur31(January, 2025, a25); %readdur31(February, 2025, a25); %readdur31(March, 2025, a25); %readdur31(April, 2025, a25);
%readdur31(January, 2026, a26); %readdur31(February, 2026, a26); %readdur31(March, 2026, a26); %readdur31(April, 2026, a26);
proc sql;
    create table DURP31 as select practice as practice_code length=10, wave,
           case when sum(ans) > 0 then 100*sum(ans120)/sum(ans) else . end as L2
    from DUR31 group by practice, wave;
quit;
proc sort data=DURP31; by practice_code; run;

%macro aset31(tag, yr, out, extra=1);
    data &out;
        merge SV(in=s) w_&tag(in=t) DURP31(where=(wave="&tag") rename=(L2=L2x));
        by practice_code;
        if s and t and ease_&yr ne . and n_eval_&yr > 0 and L2x ne . and (&extra);
        y = ease_&yr; w = n_eval_&yr;
        xA = A_&tag; xB = B_&tag; xAs = As_&tag; xBs = Bs_&tag; xW = W_&tag; xL2 = L2x; dev = dev_&tag;
        if nmiss(of xA xB xAs xBs xW xL2) = 0;
        keep practice_code y w xA xB xAs xBs xW xL2 dev;
    run;
%mend;
%macro r2_31(in);
    %local m v;
    %do m = 1 %to 6;
        %let v = %scan(xA xB xAs xBs xW xL2, &m);
        proc reg data=&in outest=_e&m(keep=_RSQ_) rsquare noprint; weight w; model y = &v; run; quit;
        data _e&m; set _e&m; length measure $4; measure = "&v"; rename _RSQ_ = r2; run;
    %end;
    proc sql noprint; select count(*) into :_n trimmed from &in; quit;
    data R31_&in; set _e1-_e6; n = &_n; run;
%mend;
%macro boot31(in);
    proc surveyselect data=&in out=_b method=urs samprate=1 reps=&NBOOT31 outhits seed=&SEED31 noprint; run;
    %local m v;
    %do m = 1 %to 3;
        %let v = %scan(xA xW xL2, &m);
        proc reg data=_b outest=_f&m(keep=Replicate _RSQ_) rsquare noprint; by Replicate; weight w; model y = &v; run; quit;
        data _f&m; set _f&m; rename _RSQ_ = r&m; run;
    %end;
    data _bd; merge _f1 _f2 _f3; by Replicate; dWA = r2 - r1; dLA = r3 - r1; run;
    proc univariate data=_bd noprint; var dWA dLA; output out=BQ31_&in pctlpts=2.5 97.5 pctlpre=WA_ LA_; run;
%mend;

/* check program 31 part 1: six month windows on the practices also present in the January to March sets */
%aset31(q25, 2025, Q25); %aset31(q26, 2026, Q26);
%aset31(s25, 2025, S25); %aset31(s26, 2026, S26);
proc sql;
    create table S25c as select * from S25 where practice_code in (select practice_code from Q25);
    create table Q25c as select * from Q25 where practice_code in (select practice_code from S25c);
    create table S26c as select * from S26 where practice_code in (select practice_code from Q26);
    create table Q26c as select * from Q26 where practice_code in (select practice_code from S26c);
quit;
%r2_31(Q25c); %r2_31(S25c); %r2_31(Q26c); %r2_31(S26c);
%boot31(S25c); %boot31(S26c);

/* check program 31 part 2: recorded outcomes v inbound calls */
proc sql;
    create table C31_DEV as
    select '2025' as wave length=4, count(*) as practices, sum(abs(dev) > 0.05) as over_5pct from Q25
    union all
    select '2026', count(*), sum(abs(dev) > 0.05) from Q26;
quit;
%aset31(q25, 2025, M25, extra=%str(abs(dev_q25) <= 0.05)); %aset31(q26, 2026, M26, extra=%str(abs(dev_q26) <= 0.05));
%r2_31(M25); %r2_31(M26); %r2_31(Q25); %r2_31(Q26);
%boot31(M25); %boot31(M26);

/* check program 32 part 1: January to April window, common sample with January to March */
%aset31(a25, 2025, A25); %aset31(a26, 2026, A26);
proc sql;
    create table A25c as select * from A25 where practice_code in (select practice_code from Q25);
    create table Q25j as select * from Q25 where practice_code in (select practice_code from A25c);
    create table A26c as select * from A26 where practice_code in (select practice_code from Q26);
    create table Q26j as select * from Q26 where practice_code in (select practice_code from A26c);
quit;
%r2_31(Q25j); %r2_31(A25c); %r2_31(Q26j); %r2_31(A26c);
%boot31(A25c); %boot31(A26c);

/* check program 32 part 3: at least the median number of respondents */
proc means data=Q25 noprint; var w; output out=_m25 median=med; run;
proc means data=Q26 noprint; var w; output out=_m26 median=med; run;
data R25; if _n_ = 1 then set _m25(keep=med); set Q25; if w >= med; drop med; run;
data R26; if _n_ = 1 then set _m26(keep=med); set Q26; if w >= med; drop med; run;
%r2_31(R25); %r2_31(R26);
%boot31(R25); %boot31(R26);

/* differences R2(W) - R2(A), one row per set */
%macro _d31(set);
    proc sql;
        create table _dd as
        select "&set" as set length=8,
               (select r2 from R31_&set where measure = 'xW') - (select r2 from R31_&set where measure = 'xA') as dWA,
               (select n from R31_&set where measure = 'xA') as n
        from _one;
    quit;
    proc append base=D31 data=_dd force; run;
%mend;
proc datasets lib=work nolist nowarn; delete D31; quit;
%_d31(Q25c); %_d31(Q26c); %_d31(S25c); %_d31(S26c); %_d31(M25); %_d31(M26); %_d31(Q25j); %_d31(Q26j);
%_d31(A25c); %_d31(A26c); %_d31(R25); %_d31(R26);
* end of MS_c3132.sas ;

/* summaries used by several rows */
proc sql;
    /* ranges over the five definitions, log rate (LR) and Poisson (PO) */
    create table _rng as
    select est, level, min(rr) as lo, max(rr) as hi, sum(round(rr, 0.01) > 1) as n_above, count(*) as n_def
    from S1RR where defn in ('A', 'B', 'As', 'Bs', 'W') group by est, level;
    /* bank holidays: largest change, rows inside the main interval, among the nine interpreted rate ratios */
    create table _bh as
    select max(abs(rr_xh - rr_orig)) as maxchg, sum(inside) as n_inside, count(*) as n_rr
    from C24_P1 where in_rule = 1;
    /* Monday rush across the three periods and three definitions */
    create table _mon27 as select min(rr) as lo, max(rr) as hi from RR27 where level = 'rush_Mon';
    /* waiting time: R2(W) - R2(L2) */
    create table _wl as
    select a.wave, a.r2 - b.r2 as d, c.WL_2_5, c.WL_97_5
    from C25_R2 a inner join C25_R2 b on a.wave = b.wave and a.tag = 'xW' and b.tag = 'L2'
         inner join C25_BQ c on a.wave = c.wave;
    /* main R2 difference, January to March (table 2) */
    create table _t2d as
    select (select r2_25 from T2R2 where tag = 'W') - (select r2_25 from T2R2 where tag = 'A') as d25,
           (select r2_26 from T2R2 where tag = 'W') - (select r2_26 from T2R2 where tag = 'A') as d26
    from _one;
quit;
proc sql;
    create table _d31 as
    select a.set, a.dWA, a.n, b.WA_2_5, b.WA_97_5
    from D31 a left join
         (select 'S25c' as set length=8, WA_2_5, WA_97_5 from BQ31_S25c
          union all select 'S26c', WA_2_5, WA_97_5 from BQ31_S26c
          union all select 'M25',  WA_2_5, WA_97_5 from BQ31_M25
          union all select 'M26',  WA_2_5, WA_97_5 from BQ31_M26
          union all select 'A25c', WA_2_5, WA_97_5 from BQ31_A25c
          union all select 'A26c', WA_2_5, WA_97_5 from BQ31_A26c
          union all select 'R25',  WA_2_5, WA_97_5 from BQ31_R25
          union all select 'R26',  WA_2_5, WA_97_5 from BQ31_R26) b
    on a.set = b.set;
quit;
data _c23; merge C23C C23C_CI; run;
data _sii; merge SII_PT(where=(measure='A')) SII_CI; run;


/* ---- results, in the order of the table ---- */
/* 1. Definition of a failed call */
%add(101, Definition of a failed call, Main estimate, Abandonment Monday rush RR, ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='A' and level='rush_Mon'));
%add(102, Definition of a failed call, Main estimate, Abandonment midday RR,      ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='A' and level='midday'));
%add(103, Definition of a failed call, Under the check, Monday rush range over the five definitions, rng(lo, hi, 2), ds=_rng, wh=%str(est='LR' and level='rush_Mon'));
%add(104, Definition of a failed call, Under the check, definitions with Monday rush RR above 1, fi(n_above), ds=_rng, wh=%str(est='LR' and level='rush_Mon'));
%add(105, Definition of a failed call, Under the check, midday range over the five definitions, rng(lo, hi, 2), ds=_rng, wh=%str(est='LR' and level='midday'));

/* 2. Abandoned plus menu ended */
%add(201, Abandoned plus menu ended, Under the check, Monday rush,    ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='AM' and level='rush_Mon'));
%add(202, Abandoned plus menu ended, Under the check, midday,         ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='AM' and level='midday'));
%add(203, Abandoned plus menu ended, Under the check, late afternoon, ci(rr, lcl, ucl, 2), ds=S1RR, wh=%str(est='LR' and defn='AM' and level='late'));
%add(204, Abandoned plus menu ended, Under the check, Poisson midday,         fn(rr, 2), ds=S1RR, wh=%str(est='PO' and defn='AM' and level='midday'));
%add(205, Abandoned plus menu ended, Under the check, Poisson late afternoon, fn(rr, 2), ds=S1RR, wh=%str(est='PO' and defn='AM' and level='late'));

/* 3. Estimator */
%add(301, Estimator, Under the check, Poisson Monday rush range, rng(lo, hi, 2), ds=_rng, wh=%str(est='PO' and level='rush_Mon'));
%add(302, Estimator, Under the check, Poisson midday range,      rng(lo, hi, 2), ds=_rng, wh=%str(est='PO' and level='midday'));
%add(303, Estimator, Under the check, Poisson abandonment Monday rush,       fn(rr, 2), ds=S1RR, wh=%str(est='PO' and defn='A' and level='rush_Mon'));
%add(304, Estimator, Under the check, Poisson abandonment midday,            fn(rr, 2), ds=S1RR, wh=%str(est='PO' and defn='A' and level='midday'));
%add(305, Estimator, Under the check, least squares abandonment Monday rush, fn(rr, 2), ds=S1RR, wh=%str(est='LR' and defn='A' and level='rush_Mon'));
%add(306, Estimator, Under the check, least squares abandonment midday,      fn(rr, 2), ds=S1RR, wh=%str(est='LR' and defn='A' and level='midday'));

/* 4. Exposure rebuilt from daily source files */
%add(401, Daily source files, Main estimate, Monday rush abandonment (monthly panel),              fn(rr, 2), ds=S1RR, wh=%str(est='LR' and defn='A' and level='rush_Mon'));
%add(402, Daily source files, Main estimate, Monday rush real time non-connection (monthly panel), fn(rr, 2), ds=S1RR, wh=%str(est='LR' and defn='B' and level='rush_Mon'));
%add(403, Daily source files, Under the check, ordinary Monday abandonment,               ci(rr, lcl, ucl, 2), ds=bA, wh=%str(level='ordinary_Monday'));
%add(404, Daily source files, Under the check, ordinary Monday real time non-connection,  ci(rr, lcl, ucl, 2), ds=bB, wh=%str(level='ordinary_Monday'));
%add(405, Daily source files, Under the check, post-holiday Tuesday abandonment,              ci(rr, lcl, ucl, 2), ds=bA, wh=%str(level='postholiday_Tuesday'));
%add(406, Daily source files, Under the check, post-holiday Tuesday real time non-connection, ci(rr, lcl, ucl, 2), ds=bB, wh=%str(level='postholiday_Tuesday'));

/* 5. Bank holidays removed */
%add(501, Bank holidays removed, Under the check, largest change in a rate ratio, fn(maxchg, 2), ds=_bh);
%add(502, Bank holidays removed, Under the check, rate ratios within the main 95% CI, strip(fi(n_inside)) || ' of ' || strip(fi(n_rr)), ds=_bh);
%add(503, Bank holidays removed, Under the check, total non-connection Monday rush without holidays, ci(rr_xh, lcl_xh, ucl_xh, 2), ds=C24_P1, wh=%str(model='W' and level='rush_Mon'));
%add(504, Bank holidays removed, Under the check, total non-connection Monday rush main,             ci(rr_orig, lcl_orig, ucl_orig, 2), ds=C24_P1, wh=%str(model='W' and level='rush_Mon'));

/* 6. Period of the time cell comparisons */
%add(601, Period of the time cell comparisons, Main estimate, practices October 2025 to June 2026, fi(practices), ds=N27, wh=%str(win='STAB'));
%add(602, Period of the time cell comparisons, Main estimate, midday abandonment,              ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='STAB' and level='midday' and model=:'A'));
%add(603, Period of the time cell comparisons, Main estimate, midday real time non-connection, ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='STAB' and level='midday' and model=:'B'));
%add(604, Period of the time cell comparisons, Main estimate, midday total non-connection,     ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='STAB' and level='midday' and model=:'W'));
%add(611, Period of the time cell comparisons, Under the check, months in the whole series,    fi(months), ds=N27, wh=%str(win='FULL'));
%add(612, Period of the time cell comparisons, Under the check, practices all months,          fi(practices), ds=N27, wh=%str(win='FULL'));
%add(613, Period of the time cell comparisons, Under the check, all months midday abandonment,              ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='FULL' and level='midday' and model=:'A'));
%add(614, Period of the time cell comparisons, Under the check, all months midday real time non-connection, ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='FULL' and level='midday' and model=:'B'));
%add(615, Period of the time cell comparisons, Under the check, all months midday total non-connection,     ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='FULL' and level='midday' and model=:'W'));
%add(621, Period of the time cell comparisons, Under the check, practices October 2024 to September 2025,   fi(practices), ds=N27, wh=%str(win='PRE'));
%add(622, Period of the time cell comparisons, Under the check, October 2024 to September 2025 midday abandonment,              ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='PRE' and level='midday' and model=:'A'));
%add(623, Period of the time cell comparisons, Under the check, October 2024 to September 2025 midday real time non-connection, ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='PRE' and level='midday' and model=:'B'));
%add(624, Period of the time cell comparisons, Under the check, October 2024 to September 2025 midday total non-connection,     ci(rr, lcl, ucl, 2), ds=RR27, wh=%str(win='PRE' and level='midday' and model=:'W'));
%add(631, Period of the time cell comparisons, Under the check, Monday rush range over periods and definitions, rng(lo, hi, 2), ds=_mon27);

/* 7. Period of the deprivation comparison */
%add(701, Period of the deprivation comparison, Main estimate, abandonment most v least deprived,   ci(pt, lcl, ucl, 2), ds=DEP27, wh=%str(win='STAB' and measure='A'));
%add(702, Period of the deprivation comparison, Main estimate, Monday rush most v least deprived,   ci(pt, lcl, ucl, 2), ds=DEP27, wh=%str(win='STAB' and measure='Monday A'));
%add(703, Period of the deprivation comparison, Under the check, all months abandonment,            ci(pt, lcl, ucl, 2), ds=DEP27, wh=%str(win='FULL' and measure='A'));
%add(704, Period of the deprivation comparison, Under the check, all months Monday rush,            ci(pt, lcl, ucl, 2), ds=DEP27, wh=%str(win='FULL' and measure='Monday A'));
%add(705, Period of the deprivation comparison, Under the check, October 2024 to September 2025 abandonment, ci(pt, lcl, ucl, 2), ds=DEP27, wh=%str(win='PRE' and measure='A'));
%add(706, Period of the deprivation comparison, Under the check, October 2024 to September 2025 Monday rush, ci(pt, lcl, ucl, 2), ds=DEP27, wh=%str(win='PRE' and measure='Monday A'));

/* 8. Practices without recorded callback use */
%add(801, Practices without recorded callback use, Main estimate, midday RR all practices,          fn(rr, 2), ds=S1RR, wh=%str(est='LR' and defn='A' and level='midday'));
%add(802, Practices without recorded callback use, Under the check, midday RR without callback use, fn(rr, 2), ds=c0, wh=%str(level='midday'));
%add(803, Practices without recorded callback use, Under the check, midday RR callback practices,   fn(rr, 2), ds=c1, wh=%str(level='midday'));

/* 9. Callback intensity tertiles */
%add(901, Callback intensity tertiles, Under the check, Monday rush lowest tertile,  fn(rr, 2), ds=ct1, wh=%str(level='rush_Mon'));
%add(902, Callback intensity tertiles, Under the check, Monday rush middle tertile,  fn(rr, 2), ds=ct2, wh=%str(level='rush_Mon'));
%add(903, Callback intensity tertiles, Under the check, Monday rush highest tertile, fn(rr, 2), ds=ct3, wh=%str(level='rush_Mon'));
%add(904, Callback intensity tertiles, Under the check, midday lowest tertile,       fn(rr, 2), ds=ct1, wh=%str(level='midday'));
%add(905, Callback intensity tertiles, Under the check, midday middle tertile,       fn(rr, 2), ds=ct2, wh=%str(level='midday'));
%add(906, Callback intensity tertiles, Under the check, midday highest tertile,      fn(rr, 2), ds=ct3, wh=%str(level='midday'));

/* 10. Where the variation sits */
%add(1001, Variance components, Main estimate (call weighted), practices,                pc(vpc_pct, 1), ds=VPC_B, wh=%str(Subject='practice_code'));
%add(1002, Variance components, Main estimate (call weighted), months within a practice, pc(vpc_pct, 1), ds=VPC_B, wh=%str(CovParm='Residual'));
%add(1003, Variance components, Main estimate (call weighted), networks,                 pc(vpc_pct, 1), ds=VPC_B, wh=%str(Subject='pcn_code'));
%add(1004, Variance components, Main estimate (call weighted), districts,                pc(vpc_pct, 1), ds=VPC_B, wh=%str(Subject='lad_code'));
%add(1005, Variance components, Under the check (unweighted), practices,                 pc(vpc_pct, 1), ds=VPC_A, wh=%str(Subject='practice_code'));
%add(1006, Variance components, Under the check (unweighted), months within a practice,  pc(vpc_pct, 1), ds=VPC_A, wh=%str(CovParm='Residual'));
%add(1007, Variance components, Under the check (unweighted), networks,                  pc(vpc_pct, 1), ds=VPC_A, wh=%str(Subject='pcn_code'));
%add(1008, Variance components, Under the check (unweighted), districts,                 pc(vpc_pct, 1), ds=VPC_A, wh=%str(Subject='lad_code'));

/* 11. Practices sharing a postcode */
%add(1101, Practices sharing a postcode, Main estimate, between-practice R2 total non-connection 2026, fn(r2_26, 2), ds=T2R2, wh=%str(tag='W'));
%add(1102, Practices sharing a postcode, Under the check, within-site r abandonment,          fn(r_A, 2), ds=S5P1R);
%add(1103, Practices sharing a postcode, Under the check, within-site r total non-connection, fn(r_W, 2), ds=S5P1R);
%add(1104, Practices sharing a postcode, Under the check, within-site variation explained by staffing list size call volume and callback intensity, pc(100 * r2, 1), ds=S5P2R2);
%add(1105, Practices sharing a postcode, Under the check, menu ended with site fixed effects and site clustered SE, ci(Estimate, LowerCL, UpperCL, 2), ds=C24_P2, wh=%str(Parameter='menu_w26'));

/* 12. Practice covariates */
%add(1201, Practice covariates, Main estimate, R2 abandonment 2026,          fn(r2_26, 2), ds=T2R2, wh=%str(tag='A'));
%add(1202, Practice covariates, Main estimate, R2 total non-connection 2026, fn(r2_26, 2), ds=T2R2, wh=%str(tag='W'));
%add(1203, Practice covariates, Under the check, increase over covariates abandonment,          fn(increment, 2), ds=C24_P4, wh=%str(tag='A'));
%add(1204, Practice covariates, Under the check, increase over covariates total non-connection, fn(increment, 2), ds=C24_P4, wh=%str(tag='W'));
%add(1205, Practice covariates, Under the check, difference,                                    ci(diff, p2_5, p97_5, 2), ds=C24_P4D);
%add(1206, Practice covariates, Under the check, extended covariates difference 2026, ci(d_W_A, p2_5, p97_5, 2), ds=C25_P3, wh=%str(variant='2026 full'));
%add(1207, Practice covariates, Under the check, extended covariates difference 2025, ci(d_W_A, p2_5, p97_5, 2), ds=C25_P3, wh=%str(variant='2025 full'));
%add(1208, Practice covariates, Under the check, unadjusted difference with networks resampled 2026, rng(p2_5, p97_5, 2), ds=C25_P4, wh=%str(wave='2026'));

/* 13. Waiting time to answer as a comparator */
%add(1301, Waiting time to answer, Main estimate, R2 total non-connection 2026, fn(r2_26, 2), ds=T2R2, wh=%str(tag='W'));
%add(1302, Waiting time to answer, Under the check, R2 answered calls waiting more than 2 min 2026, fn(r2, 2), ds=C25_R2, wh=%str(wave='2026' and tag='L2'));
%add(1303, Waiting time to answer, Under the check, R2 answered calls waiting more than 2 min 2025, fn(r2, 2), ds=C25_R2, wh=%str(wave='2025' and tag='L2'));
%add(1304, Waiting time to answer, Under the check, difference from total non-connection 2026, ci(d, WL_2_5, WL_97_5, 2), ds=_wl, wh=%str(wave='2026'));
%add(1305, Waiting time to answer, Under the check, difference from total non-connection 2025, ci(d, WL_2_5, WL_97_5, 2), ds=_wl, wh=%str(wave='2025'));
%add(1306, Waiting time to answer, Under the check, R2 more than 5 min 2026, fn(r2, 2), ds=C25_R2, wh=%str(wave='2026' and tag='L5'));
%add(1307, Waiting time to answer, Under the check, R2 more than 5 min 2025, fn(r2, 2), ds=C25_R2, wh=%str(wave='2025' and tag='L5'));

/* 14. All linked practices */
%add(1401, All linked practices, Main estimate, R2 abandonment 2025, fn(r2_25, 2), ds=T2R2, wh=%str(tag='A'));
%add(1402, All linked practices, Main estimate, R2 abandonment 2026, fn(r2_26, 2), ds=T2R2, wh=%str(tag='A'));
%add(1403, All linked practices, Under the check, R2 abandonment 2025 all linked practices, ci(R2_A, A_2_5, A_97_5, 2), ds=_c23);
%add(1404, All linked practices, Under the check, practices 2025, fi(n), ds=_c23);

/* 15. Telephony window for the survey link */
%add(1501, Telephony window, Main estimate, difference in R2 total non-connection minus abandonment 2025, fn(d25, 2), ds=_t2d);
%add(1502, Telephony window, Main estimate, difference in R2 total non-connection minus abandonment 2026, fn(d26, 2), ds=_t2d);
%add(1503, Telephony window, Under the check, January to April 2025,  ci(dWA, WA_2_5, WA_97_5, 2), ds=_d31, wh=%str(set='A25c'));
%add(1504, Telephony window, Under the check, January to April 2026,  ci(dWA, WA_2_5, WA_97_5, 2), ds=_d31, wh=%str(set='A26c'));
%add(1505, Telephony window, Under the check, October to March 2025,  ci(dWA, WA_2_5, WA_97_5, 2), ds=_d31, wh=%str(set='S25c'));
%add(1506, Telephony window, Under the check, October to March 2026,  ci(dWA, WA_2_5, WA_97_5, 2), ds=_d31, wh=%str(set='S26c'));

/* 16. Practices with at least the median number of survey respondents */
%add(1601, Median respondents, Under the check, practices 2025, fi(n), ds=_d31, wh=%str(set='R25'));
%add(1602, Median respondents, Under the check, practices 2026, fi(n), ds=_d31, wh=%str(set='R26'));
%add(1603, Median respondents, Under the check, difference 2025, ci(dWA, WA_2_5, WA_97_5, 2), ds=_d31, wh=%str(set='R25'));
%add(1604, Median respondents, Under the check, difference 2026, ci(dWA, WA_2_5, WA_97_5, 2), ds=_d31, wh=%str(set='R26'));

/* 17. Recorded outcomes not summing to inbound calls */
%add(1701, Recorded outcomes not summing to inbound calls, Main estimate, difference 2025, fn(dWA, 2), ds=_d31, wh=%str(set='Q25c'));
%add(1702, Recorded outcomes not summing to inbound calls, Under the check, such practices 2025, fi(over_5pct), ds=C31_DEV, wh=%str(wave='2025'));
%add(1703, Recorded outcomes not summing to inbound calls, Under the check, such practices 2026, fi(over_5pct), ds=C31_DEV, wh=%str(wave='2026'));
%add(1704, Recorded outcomes not summing to inbound calls, Under the check, difference 2025 without them, ci(dWA, WA_2_5, WA_97_5, 2), ds=_d31, wh=%str(set='M25'));

/* 18. Within-practice change and falsification test */
%add(1801, Within-practice change, Main estimate (across practices 2026), abandoned,         fn(coef, 2), ds=T2P2, wh=%str(model='a26' and comp='A'));
%add(1802, Within-practice change, Main estimate (across practices 2026), callback diverted, fn(coef, 2), ds=T2P2, wh=%str(model='a26' and comp='cb'));
%add(1803, Within-practice change, Main estimate (across practices 2026), menu ended,        fn(coef, 2), ds=T2P2, wh=%str(model='a26' and comp='menu'));
%add(1804, Within-practice change, First differences, abandoned,         ci(coef, lo, hi, 2), ds=T2P2, wh=%str(model='fd' and comp='A'));
%add(1805, Within-practice change, First differences, callback diverted, ci(coef, lo, hi, 2), ds=T2P2, wh=%str(model='fd' and comp='cb'));
%add(1806, Within-practice change, First differences, menu ended,        ci(coef, lo, hi, 2), ds=T2P2, wh=%str(model='fd' and comp='menu'));
%add(1807, Within-practice change, Falsification test, abandoned,         cis(coef, lo, hi, 2), ds=T2P2, wh=%str(model='fals' and comp='A'));
%add(1808, Within-practice change, Falsification test, callback diverted, cis(coef, lo, hi, 2), ds=T2P2, wh=%str(model='fals' and comp='cb'));
%add(1809, Within-practice change, Falsification test, menu ended,        cis(coef, lo, hi, 2), ds=T2P2, wh=%str(model='fals' and comp='menu'));
%add(1810, Within-practice change, Test with 2025 levels added, abandoned,         cis(coef, lo, hi, 2), ds=C24_P3, wh=%str(tag='levels' and var='dA'));
%add(1811, Within-practice change, Test with 2025 levels added, callback diverted, cis(coef, lo, hi, 2), ds=C24_P3, wh=%str(tag='levels' and var='dcb'));
%add(1812, Within-practice change, Test with 2025 levels added, menu ended,        cis(coef, lo, hi, 2), ds=C24_P3, wh=%str(tag='levels' and var='dmenu'));

/* 19. Opening hours only */
%add(1901, Opening hours only, Main estimate (2026 all hours), abandoned,         fn(coef, 2), ds=T2P2, wh=%str(model='a26' and comp='A'));
%add(1902, Opening hours only, Main estimate (2026 all hours), callback diverted, fn(coef, 2), ds=T2P2, wh=%str(model='a26' and comp='cb'));
%add(1903, Opening hours only, Main estimate (2026 all hours), menu ended,        fn(coef, 2), ds=T2P2, wh=%str(model='a26' and comp='menu'));
%add(1904, Opening hours only, Under the check (2026 opening hours), abandoned,         ci(coef, lo, hi, 2), ds=T2P2, wh=%str(model='a26h' and comp='A'));
%add(1905, Opening hours only, Under the check (2026 opening hours), callback diverted, ci(coef, lo, hi, 2), ds=T2P2, wh=%str(model='a26h' and comp='cb'));
%add(1906, Opening hours only, Under the check (2026 opening hours), menu ended,        ci(coef, lo, hi, 2), ds=T2P2, wh=%str(model='a26h' and comp='menu'));

/* 20. Balanced panel */
%add(2001, Balanced panel, Check, practices,          fi(n_bal),    ds=S3S);
%add(2002, Balanced panel, Check, months,             fi(n_months), ds=S3S);
%add(2003, Balanced panel, Under the check, rush share October 2024,        pc(rush_share, 1), ds=S3M, wh=%str(month='202410'));
%add(2004, Balanced panel, Under the check, rush share June 2026,           pc(rush_share, 1), ds=S3M, wh=%str(month='202606'));
%add(2005, Balanced panel, Under the check, rush abandonment October 2024,  pc(a_rush, 1),     ds=S3M, wh=%str(month='202410'));
%add(2006, Balanced panel, Under the check, rush abandonment June 2026,     pc(a_rush, 1),     ds=S3M, wh=%str(month='202606'));
%add(2007, Balanced panel, Under the check, rest of day October 2024,       pc(a_rest, 1),     ds=S3M, wh=%str(month='202410'));
%add(2008, Balanced panel, Under the check, rest of day June 2026,          pc(a_rest, 1),     ds=S3M, wh=%str(month='202606'));

/* 21. Entry cohort */
%add(2101, Entry cohort, Main estimate, ease 2024 all practices, pc(e2024, 1), ds=S7, wh=%str(ord=5));
%add(2102, Entry cohort, Main estimate, ease 2026 all practices, pc(e2026, 1), ds=S7, wh=%str(ord=5));
%add(2103, Entry cohort, Under the check, change entered 2024,                    sg(change, 1), ds=S7, wh=%str(ord=1));
%add(2104, Entry cohort, Under the check, change entered January to September 2025, sg(change, 1), ds=S7, wh=%str(ord=2));
%add(2105, Entry cohort, Under the check, change entered from October 2025,      sg(change, 1), ds=S7, wh=%str(ord=3));
%add(2106, Entry cohort, Under the check, change never in the collection,        sg(change, 1), ds=S7, wh=%str(ord=4));

/* 22. Deprivation gradient across all ten deciles */
%add(2201, Deprivation gradient, Main estimate, ratio of most to least deprived decile means abandonment, ci(pt, lcl, ucl, 2), ds=DEP27, wh=%str(win='STAB' and measure='A'));
%add(2202, Deprivation gradient, Under the check, slope index of inequality (percentage points), ci(SII, sii_A_lo, sii_A_hi, 1), ds=_sii);
%add(2203, Deprivation gradient, Under the check, relative index of inequality,                  ci(RII, rii_A_lo, rii_A_hi, 2), ds=_sii);
%add(2204, Deprivation gradient, Under the check, relative index in ratio form,                  ci(RIIr, riir_A_lo, riir_A_hi, 2), ds=_sii);

%ms_write;

* Table S4 (TS4_tableS4) ;
%fresh;

/* TS4_tableS4.sas - Table S4. Comparison with the GP Patient Survey: time cells and the outcome items.
   Every number in table S4 and its footnote, written to output\TS4_tableS4.txt.
   Derived from the table program, sections TABLE S2 PANEL 1, PANEL 2 and PANEL 3 (the program's
   'TABLE S2' is the manuscript's table S4), and its common dataset XA (time cells, October 2025 to June 2026).
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only).  ASCII only.
   Run: RUN_TS4_tableS4.bat */

%let PROG = TS4_tableS4;
%let EXH  = Table S4;
* from MS_setup.sas ;
/* MS_setup.sas - common set-up for the supplementary table programs TS1 to TS5.  INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder), PROG (its own name) and EXH (the exhibit label) first.
   Does:  options; ODS output excluded (programs compute quietly); 00_paths.sas (one folder up);
          the estimator macros (MS_wls.sas, MS_fe_cr0.sas, MS_ppml.sas); number formatting functions;
          the results table RES, the macro %add that puts one number into it, and %ms_write that writes
          RES to output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;   /* nothing is printed; results go to RES and output\PROG.txt */

/* the output file of this table, in the folder OUT (PART 0) */
%macro _ms_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_ms_dirs;

* input folders and libraries: set once in PART 1 ;
* MS_wls macros: defined in PART 3 ;
* MS_fe_cr0 macros: defined in PART 3 ;
* MS_ppml macros: defined in PART 3 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.msfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values (falsification rows of table S2) */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if input(s, best32.) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    function cis(e, l, h, d) $ 120;
        length s $120;
        s = strip(sg(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 72 713) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
run;
options cmplib=work.msfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(12), part char(80), row char(160), col char(80), value char(120));
quit;

/* %add(order, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro add(o, part, row, col, val, ds=_one, wh=1);
    %local _n;
    data _addrow;
        set &ds;
        where &wh;
        length _x_exh $12 _x_part $80 _x_row $160 _x_col $80 _x_val $120;
        _x_ord = &o; _x_exh = "&EXH"; _x_part = "&part"; _x_row = "&row"; _x_col = "&col";
        _x_val = &val;
        keep _x_ord _x_exh _x_part _x_row _x_col _x_val;
    run;
    proc sql noprint; select count(*) into :_n trimmed from _addrow; quit;
    %if &_n ne 1 %then %do; %put ERROR: add &o selected &_n rows instead of one.; %abort cancel; %end;
    proc append base=RES force
        data=_addrow(rename=(_x_ord=ord _x_exh=exhibit _x_part=part _x_row=row _x_col=col _x_val=value));
    run;
%mend;

%macro ms_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MS_setup.sas ;

%let STABLE = 202510;
%let W26    = %str('202601','202602','202603');

/* LK: the survey link, as the table program */
data LK;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
run;

/* Panel 1: correlation of each time cell's failure rate with ease, January to March 2026 (the table program TABLE S2 PANEL 1) */
proc sql;
    create table _cellr as
    select practice as practice_code, cell,
           100 * sum(CBT004) / sum(CBT001)             as A_cell,
           100 * (sum(CBT004) + sum(CBT005)) / sum(CBT001) as B_cell
    from perm.cell_daytime
    where month in (&W26) and cell ne 'pre8'
    group by practice, cell having sum(CBT001) > 0;
    create table _cellr2 as
    select a.*, b.ease_2026 from _cellr a inner join LK b
      on a.practice_code = b.practice_code where b.ease_2026 ne .;
    create table s2p1 as
    select cell, count(*) as n,
           (mean(A_cell * ease_2026) - mean(A_cell) * mean(ease_2026)) /
           (std(A_cell) * std(ease_2026)) * (count(*) / (count(*) - 1)) as r_A,
           (mean(B_cell * ease_2026) - mean(B_cell) * mean(ease_2026)) /
           (std(B_cell) * std(ease_2026)) * (count(*) / (count(*) - 1)) as r_B
    from _cellr2 group by cell;
    create table _p1n as select max(n) as n from s2p1;
quit;

/* Panel 2: how respondents' last phone contact ended v the telephony record (the table program TABLE S2 PANEL 2) */
data _o26; set LK; where Ah_w26 ne . and cb_asked_2026 ne .; run;
proc sql;
    create table s2p2 as
    select 'cb' as item length=8,
           sum(n_outcome_2026 * cb_asked_2026)  / sum(n_outcome_2026) as patient,
           sum(inb_w26 * cbh_w26)               / sum(inb_w26)        as record
    from _o26
    union all
    select 'ab',
           sum(n_outcome_2026 * aband_rep_2026) / sum(n_outcome_2026),
           sum(inb_w26 * Ah_w26)                / sum(inb_w26)
    from _o26
    union all
    select 'na',
           sum(n_outcome_2026 * notans_rep_2026) / sum(n_outcome_2026),
           sum(inb_w26 * menuh_w26)              / sum(inb_w26)
    from _o26;
quit;
/* footnote: practice medians of the abandoned and not answered categories (same sample) */
proc means data=_o26 noprint;
    var aband_rep_2026 notans_rep_2026;
    output out=_med median = med_ab med_na;
run;

/* Panel 3: validation of the callback count and the no contact and timing items (the table program TABLE S2 PANEL 3) */
data _o26;
    set LK;
    where Ah_w26 ne . and cb_asked_2026 ne .;
    Bh_w26 = Ah_w26 + cbh_w26;
run;
%wls(data=_o26, y=cb_asked_2026,   x=cbh_w26,                 w=n_outcome_2026, out=_v1,
     tag=callback share across practices);
%wls(data=_o26, y=no_contact_2026, x=Ah_w26 cbh_w26 menuh_w26, w=n_next_2026,   out=_v2,
     tag=could not contact the practice);
%wls(data=_o26, y=timing_now_2026, x=Ah_w26 cbh_w26 menuh_w26, w=n_next_2026,   out=_v3,
     tag=learned the next step there and then);
data _oc;
    set LK;
    where Ah_w25 ne . and Ah_w26 ne . and cb_asked_2025 ne . and cb_asked_2026 ne .;
    dcbask = cb_asked_2026 - cb_asked_2025;
    dA     = Ah_w26   - Ah_w25;
    dcb    = cbh_w26  - cbh_w25;
    dmenu  = menuh_w26 - menuh_w25;
    w      = min(n_outcome_2025, n_outcome_2026);
run;
%wls(data=_oc, y=dcbask, x=dA dcb dmenu, w=w, out=_v4,
     tag=callback share within practices);
data s2p3; set _v1 _v2 _v3 _v4; where upcase(var) ne 'INTERCEPT'; run;
%wlsci(in=s2p3, out=s2p3ci, dp=3);

/* footnote: share of weekday calls (06:00 to 18:30) in the midday cell, October 2025 to June 2026, the time cell
   sample of table 3 panel A (the table program XA: practices with 1000 or more weekday calls) */
proc sql;
    create table _keepA as
    select practice from perm.cell_daytime
    where month >= "&STABLE." group by practice having sum(CBT001) >= 1000;
quit;
data XA;
    set perm.cell_daytime;
    where month >= "&STABLE.";
    if _n_ = 1 then do;
        declare hash k(dataset:'_keepA'); k.definekey('practice'); k.definedone();
    end;
    if k.check() ne 0 then delete;
run;
proc sql;
    create table _mid as
    select 100 * sum(case when cell = 'midday' then CBT001 else 0 end) / sum(CBT001) as mid_share from XA;
quit;


/* ---- results, in the order of the table ---- */
%add(100, Panel 1, Header, n, fi(n), ds=_p1n);
%add(101, Panel 1, Monday rush 08:00 to 10:00,           Abandonment,              fn(r_A, 2), ds=s2p1, wh=%str(cell='rush_Mon'));
%add(102, Panel 1, Monday rush 08:00 to 10:00,           Real time non-connection, fn(r_B, 2), ds=s2p1, wh=%str(cell='rush_Mon'));
%add(103, Panel 1, Tuesday to Friday rush 08:00 to 10:00, Abandonment,             fn(r_A, 2), ds=s2p1, wh=%str(cell='rush_TueFri'));
%add(104, Panel 1, Tuesday to Friday rush 08:00 to 10:00, Real time non-connection, fn(r_B, 2), ds=s2p1, wh=%str(cell='rush_TueFri'));
%add(105, Panel 1, Midday 10:00 to 16:00,                Abandonment,              fn(r_A, 2), ds=s2p1, wh=%str(cell='midday'));
%add(106, Panel 1, Midday 10:00 to 16:00,                Real time non-connection, fn(r_B, 2), ds=s2p1, wh=%str(cell='midday'));
%add(107, Panel 1, Late afternoon 16:00 to 18:30,        Abandonment,              fn(r_A, 2), ds=s2p1, wh=%str(cell='late'));
%add(108, Panel 1, Late afternoon 16:00 to 18:30,        Real time non-connection, fn(r_B, 2), ds=s2p1, wh=%str(cell='late'));

%add(201, Panel 2, Diverted to a callback, Patient report last contact (%), fn(patient, 1), ds=s2p2, wh=%str(item='cb'));
%add(202, Panel 2, Diverted to a callback, Telephony per call (%),          fn(record, 1),  ds=s2p2, wh=%str(item='cb'));
%add(203, Panel 2, Abandoned,              Patient report last contact (%), fn(patient, 1), ds=s2p2, wh=%str(item='ab'));
%add(204, Panel 2, Abandoned,              Telephony per call (%),          fn(record, 1),  ds=s2p2, wh=%str(item='ab'));
%add(205, Panel 2, Not answered at all (survey only),            Patient report last contact (%), fn(patient, 1), ds=s2p2, wh=%str(item='na'));
%add(206, Panel 2, Ended in the automated menu (telephony only), Telephony per call (%),          fn(record, 1),  ds=s2p2, wh=%str(item='na'));

%add(301, Panel 3, %str(Callback share, across practices), Callback diverted, ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='callback share across practices' and var='cbh_w26'));
%add(302, Panel 3, %str(Callback share, across practices), R2,                fn(r2, 2),            ds=s2p3ci, wh=%str(tag='callback share across practices' and var='cbh_w26'));
%add(303, Panel 3, %str(Callback share, across practices), n,                 fi(n),                ds=s2p3ci, wh=%str(tag='callback share across practices' and var='cbh_w26'));
%add(304, Panel 3, %str(Callback share, within practices), Abandoned,         ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='callback share within practices' and var='dA'));
%add(305, Panel 3, %str(Callback share, within practices), Callback diverted, ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='callback share within practices' and var='dcb'));
%add(306, Panel 3, %str(Callback share, within practices), Menu ended,        ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='callback share within practices' and var='dmenu'));
%add(307, Panel 3, %str(Callback share, within practices), R2,                fn(r2, 2),            ds=s2p3ci, wh=%str(tag='callback share within practices' and var='dA'));
%add(308, Panel 3, %str(Callback share, within practices), n,                 fi(n),                ds=s2p3ci, wh=%str(tag='callback share within practices' and var='dA'));
%add(309, Panel 3, Could not contact the practice, Abandoned,         ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='could not contact the practice' and var='Ah_w26'));
%add(310, Panel 3, Could not contact the practice, Callback diverted, ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='could not contact the practice' and var='cbh_w26'));
%add(311, Panel 3, Could not contact the practice, Menu ended,        ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='could not contact the practice' and var='menuh_w26'));
%add(312, Panel 3, Could not contact the practice, R2,                fn(r2, 2),            ds=s2p3ci, wh=%str(tag='could not contact the practice' and var='Ah_w26'));
%add(313, Panel 3, Could not contact the practice, n,                 fi(n),                ds=s2p3ci, wh=%str(tag='could not contact the practice' and var='Ah_w26'));
%add(314, Panel 3, Learned the next step there and then, Abandoned,         ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='learned the next step there and then' and var='Ah_w26'));
%add(315, Panel 3, Learned the next step there and then, Callback diverted, ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='learned the next step there and then' and var='cbh_w26'));
%add(316, Panel 3, Learned the next step there and then, Menu ended,        ci(coef, lo, hi, 3), ds=s2p3ci, wh=%str(tag='learned the next step there and then' and var='menuh_w26'));
%add(317, Panel 3, Learned the next step there and then, R2,                fn(r2, 2),            ds=s2p3ci, wh=%str(tag='learned the next step there and then' and var='Ah_w26'));
%add(318, Panel 3, Learned the next step there and then, n,                 fi(n),                ds=s2p3ci, wh=%str(tag='learned the next step there and then' and var='Ah_w26'));

%add(401, Footnote, Panel 1, share of weekday calls in the midday cell, pc(mid_share, 0), ds=_mid);
%add(402, Footnote, Panel 2, practice median of the abandoned category,         fn(med_ab, 0), ds=_med);
%add(403, Footnote, Panel 2, practice median of the not answered at all category, fn(med_na, 0), ds=_med);
%add(404, Footnote, Panel 3, practices with a published callback figure, fi(n), ds=s2p3ci, wh=%str(tag='callback share across practices' and var='cbh_w26'));
%add(405, Footnote, Panel 3, callback slope across practices, fn(coef, 2), ds=s2p3ci, wh=%str(tag='callback share across practices' and var='cbh_w26'));
%add(406, Footnote, Panel 3, callback slope within practices between waves, fn(coef, 2), ds=s2p3ci, wh=%str(tag='callback share within practices' and var='dcb'));

%ms_write;

* Table S5 (TS5_tableS5) ;
%fresh;

/* TS5_tableS5.sas - Table S5. Online consultation use and the telephone channel.
   Every number in table S5 and its footnote, written to output\TS5_tableS5.txt.
   Derived from the table program, section TABLE S3 (the program's 'TABLE S3' is the manuscript's table S5;
   panel 1 = common dataset XOC and tertiles, panel 2 = the check program 19b two way fixed effects estimator), and
   check program 33 part 12 (footnote: capability, national medians, fold rise, medians by decile).
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only) and the June 2026 online consultation raw files (read only).
   ASCII only.  Run: RUN_TS5_tableS5.bat */

%let PROG = TS5_tableS5;
%let EXH  = Table S5;
* from MS_setup.sas ;
/* MS_setup.sas - common set-up for the supplementary table programs TS1 to TS5.  INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder), PROG (its own name) and EXH (the exhibit label) first.
   Does:  options; ODS output excluded (programs compute quietly); 00_paths.sas (one folder up);
          the estimator macros (MS_wls.sas, MS_fe_cr0.sas, MS_ppml.sas); number formatting functions;
          the results table RES, the macro %add that puts one number into it, and %ms_write that writes
          RES to output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;   /* nothing is printed; results go to RES and output\PROG.txt */

/* the output file of this table, in the folder OUT (PART 0) */
%macro _ms_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_ms_dirs;

* input folders and libraries: set once in PART 1 ;
* MS_wls macros: defined in PART 3 ;
* MS_fe_cr0 macros: defined in PART 3 ;
* MS_ppml macros: defined in PART 3 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.msfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values (falsification rows of table S2) */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if input(s, best32.) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    function cis(e, l, h, d) $ 120;
        length s $120;
        s = strip(sg(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 72 713) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
run;
options cmplib=work.msfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(12), part char(80), row char(160), col char(80), value char(120));
quit;

/* %add(order, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro add(o, part, row, col, val, ds=_one, wh=1);
    %local _n;
    data _addrow;
        set &ds;
        where &wh;
        length _x_exh $12 _x_part $80 _x_row $160 _x_col $80 _x_val $120;
        _x_ord = &o; _x_exh = "&EXH"; _x_part = "&part"; _x_row = "&row"; _x_col = "&col";
        _x_val = &val;
        keep _x_ord _x_exh _x_part _x_row _x_col _x_val;
    run;
    proc sql noprint; select count(*) into :_n trimmed from _addrow; quit;
    %if &_n ne 1 %then %do; %put ERROR: add &o selected &_n rows instead of one.; %abort cancel; %end;
    proc append base=RES force
        data=_addrow(rename=(_x_ord=ord _x_exh=exhibit _x_part=part _x_row=row _x_col=col _x_val=value));
    run;
%mend;

%macro ms_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MS_setup.sas ;


/* ---- Panel 1: practices grouped by mean online consultation use (the table program XOC and TABLE S3 PANEL 1) ---- */
data XOC;
    set perm.practice_month;
    where oc_rate_per_1000 is not missing and cbt001_inbound > 0 and list_size > 1000;
    y  = cbt004_missed / cbt001_inbound;
    yb = (cbt004_missed + cbt005_cb_requested) / cbt001_inbound;
    lc = log(cbt001_inbound);
    x  = log(1 + oc_rate_per_1000);
    calls_per_1000 = 1000 * cbt001_inbound / list_size;
    keep practice_code month y yb lc x oc_rate_per_1000 calls_per_1000
         cbt001_inbound cbt004_missed cbt005_cb_requested list_size;
run;
proc sql;
    create table _prq as
    select practice_code,
           mean(oc_rate_per_1000) as ocm,
           mean(calls_per_1000)   as callm,
           sum(cbt001_inbound) as inb, sum(cbt004_missed) as ab,
           sum(cbt005_cb_requested) as cb
    from XOC group by practice_code;
quit;
proc rank data=_prq out=_prq groups=3; var ocm; ranks ter; run;
proc means data=_prq noprint nway;
    class ter; var ocm callm;
    output out=_terq(drop=_type_ _freq_) median = med_oc med_calls;
run;
proc sql;
    create table s3p1 as
    select a.ter + 1 as tertile, count(*) as n_practices,
           100 * sum(a.ab) / sum(a.inb)          as pct_A,
           100 * sum(a.ab + a.cb) / sum(a.inb)   as pct_B
    from _prq a group by a.ter;
quit;
proc sort data=s3p1; by tertile; run;
data _terq; set _terq; tertile = ter + 1; run;
proc sort data=_terq; by tertile; run;
data s3p1;
    merge s3p1(in=_ina) _terq;
    by tertile;
    if _ina;
run;

/* ---- Panel 2: change per doubling of online use, separate practice and month fixed effects
        (the table program TABLE S3 PANEL 2 = check program 19b estimator) ---- */
data _ocreg;
    set perm.practice_month;
    where cbt_observed = 1 and list_size > 1000
      and 202501 <= input(month, best.) <= 202606
      and oc_rate_per_1000 is not null and cbt001_inbound > 0;
    mn     = input(month, best.);
    x      = log2(1 + oc_rate_per_1000);
    y_call = log(1000 * cbt001_inbound / list_size);
    y_ab   = 100 * cbt004_missed / cbt001_inbound;
    y_rt   = 100 * (cbt004_missed + cbt005_cb_requested) / cbt001_inbound;
    keep practice_code mn x y_call y_ab y_rt cbt001_inbound cbt004_missed cbt005_cb_requested;
run;
%macro _oc_dm(cls);
    proc sort data=_t; by &cls; run;
    proc means data=_t noprint nway;
        class &cls; var xx yy;
        output out=_m(keep=&cls mux muy) mean = mux muy;
    run;
    data _t;
        merge _t _m; by &cls;
        xx = xx - mux; yy = yy - muy;
        drop mux muy;
    run;
%mend;
%macro _oc_twfe(yv, lab, pct, out, src=_ocreg);
    %local _i;
    data _t;
        set &src;
        xx = x; yy = &yv;
        if nmiss(xx, yy) = 0;
        keep practice_code mn xx yy;
    run;
    %do _i = 1 %to 40;
        %_oc_dm(practice_code);
        %_oc_dm(mn);
    %end;
    proc sql noprint;
        select sum(xx*yy) format=best32.      into :sxy trimmed from _t;
        select sum(xx*xx) format=best32.      into :sxx trimmed from _t;
        select count(distinct practice_code)  into :ng  trimmed from _t;
        select count(*)                       into :nn  trimmed from _t;
    quit;
    data _e;
        set _t;
        e  = yy - (&sxy / &sxx) * xx;
        xe = xx * e;
    run;
    proc sort data=_e; by practice_code; run;
    proc means data=_e noprint nway;
        class practice_code; var xe;
        output out=_g(keep=gsum) sum = gsum;
    run;
    proc sql noprint; select sum(gsum*gsum) format=best32. into :meat trimmed from _g; quit;
    data &out;
        length outcome $48;
        outcome = "&lab";
        est = &sxy / &sxx;
        se  = sqrt(&meat) / &sxx * sqrt( (&ng/(&ng-1)) * ((&nn-1)/(&nn-(&ng+18))) );
        lo  = est - 1.96 * se;
        hi  = est + 1.96 * se;
        %if &pct = Y %then %do; est = 100*est; lo = 100*lo; hi = 100*hi; %end;
        keep outcome est lo hi;
    run;
%mend;
%_oc_twfe(y_call, calls, Y, _oc3);
%_oc_twfe(y_ab,   ab,    N, _oc1);
%_oc_twfe(y_rt,   rt,    N, _oc2);
data s3p2; set _oc3 _oc1 _oc2; run;

/* footnote: analysis set (practice months, practices, months) and the length of the telephony series */
proc sql;
    create table _set as
    select count(*) as practice_months, count(distinct practice_code) as practices, count(distinct mn) as months,
           100 * sum(cbt004_missed + cbt005_cb_requested) / sum(cbt001_inbound) as rt_level
    from _ocreg;
    create table _tel as
    select count(distinct month) as tel_months from perm.practice_month where cbt_observed = 1;
    create table _gap as select a.tel_months - b.months as shorter from _tel a, _set b;
quit;

/* ---- footnote numbers (check program 33 part 12) ---- */
data _ocs;
    set perm.practice_month;
    where cbt_observed = 1 and list_size > 1000 and 202501 <= input(month, best.) <= 202606
      and oc_rate_per_1000 is not null and cbt001_inbound > 0;
    keep practice_code month oc_rate_per_1000 pw_imd_decile_1poorest;
run;
proc means data=_ocs noprint nway; class month; var oc_rate_per_1000; output out=_ocm(drop=_type_) median=med; run;
proc means data=_ocs noprint nway; class practice_code; var oc_rate_per_1000 pw_imd_decile_1poorest;
    output out=_ocp(drop=_type_ _freq_) mean(oc_rate_per_1000)=mu max(pw_imd_decile_1poorest)=dec_set; run;
proc sql;
    create table S12m as
    select (select med from _ocm where month = '202501') as med_first,
           (select med from _ocm where month = '202606') as med_last,
           (select med from _ocm where month = '202606') / (select med from _ocm where month = '202501') as fold
    from _one;
    /* deprivation decile of the survey link (ext_link decile), the main deprivation rule */
    create table _ocpd as
    select a.mu, b.decile
    from _ocp a left join perm.ext_link b on a.practice_code = b.practice_code;
quit;
proc means data=_ocpd noprint nway; class decile; var mu; output out=_ocd(drop=_type_) median=med; run;

/* capability from the June 2026 release raw files (OC_CAPABILITY, one row per practice, month and supplier) */
%macro readcap(part);
    %local f;
    %let f = &OCDIR.\Submissions via OC Systems in General Practice - June 2026_&part._regions.csv;
    %if %sysfunc(fileexist(&f)) = 0 %then %do; %put ERROR: online consultation raw file missing: &part; %abort cancel; %end;
    %else %do;
    data _cr;
        length month_c $12 gp_code $10 metric $60;
        infile "&f" dsd truncover firstobs=2 lrecl=4096;
        input month_c $ gp_code $
              d1 : $200. d2 : $200. d3 : $200. d4 : $200. d5 : $200.
              d6 : $200. d7 : $200. d8 : $200. d9 : $200. d10 : $200.
              metric $ value;
        if metric ne 'OC_CAPABILITY' or gp_code = '' then delete;
        month_n = put(input(month_c, yymmdd10.), yymmn6.);
        keep gp_code month_n value;
    run;
    proc append base=_capraw data=_cr force; run;
    %end;
%mend;
proc datasets lib=work nolist nowarn; delete _capraw; quit;
%readcap(north); %readcap(south);
proc sql;
    create table _cap as
    select gp_code as practice_code length=10, month_n, max(value) as cap
    from _capraw group by gp_code, month_n;
    create table _capp as
    select practice_code, max(cap = 1) as ever_cap
    from _cap where '202501' <= month_n <= '202606' group by practice_code;
    create table S12c as
    select (select 100 * mean(coalesce(b.ever_cap, 0)) from (select distinct practice_code from _ocs) a
                left join _capp b on a.practice_code = b.practice_code) as ever_analysis
    from _one;
quit;

/* footnote: panel 2 without the practice months whose supplier is 'No data' in the release (the publication's notes:
   no supplier, not participating, supplier not yet submitting, or no data received that month), whose zero
   submissions can mean missing data */
%macro readsup(part);
    %local f;
    %let f = &OCDIR.\Submissions via OC Systems in General Practice - June 2026_&part._regions.csv;
    %if %sysfunc(fileexist(&f)) = 0 %then %do; %put ERROR: online consultation raw file missing: &part; %abort cancel; %end;
    data _sr;
        length month_c $12 gp_code $10 metric $60;
        infile "&f" dsd truncover firstobs=2 lrecl=4096;
        input month_c $ gp_code $
              d1 : $200. d2 : $200. d3 : $200. d4 : $200. d5 : $200.
              d6 : $200. d7 : $200. d8 : $200. d9 : $200. d10 : $200.
              metric $ value;
        if metric ne 'OC_TOTAL_SUBMISSIONS' or gp_code = '' or upcase(strip(d10)) ne 'NO DATA' then delete;
        mn = input(put(input(month_c, yymmdd10.), yymmn6.), best.);
        keep gp_code mn;
    run;
    proc append base=_ndraw data=_sr force; run;
%mend;
proc datasets lib=work nolist nowarn; delete _ndraw; quit;
%readsup(north); %readsup(south);
proc sql;
    create table _nd as select distinct gp_code as practice_code length=10, mn from _ndraw;
    create table _ocreg_x as
    select a.* from _ocreg a where not exists (select 1 from _nd b where b.practice_code = a.practice_code and b.mn = a.mn);
    create table _ndn as
    select (select count(*) from _ocreg) - (select count(*) from _ocreg_x) as n_excl from _one;
quit;
%_oc_twfe(y_call, calls, Y, _ox3, src=_ocreg_x);
%_oc_twfe(y_ab,   ab,    N, _ox1, src=_ocreg_x);
%_oc_twfe(y_rt,   rt,    N, _ox2, src=_ocreg_x);
data s3p2x; set _ox3 _ox1 _ox2; run;


/* ---- results, in the order of the table ---- */
%add(101, Panel 1, Lowest,  n,                                                    fi(n_practices),   ds=s3p1, wh=%str(tertile=1));
%add(102, Panel 1, Lowest,  Online consultations per 1000 patients per month median, fn(med_oc, 0),    ds=s3p1, wh=%str(tertile=1));
%add(103, Panel 1, Lowest,  Inbound calls per 1000 patients per month median,        fn(med_calls, 0), ds=s3p1, wh=%str(tertile=1));
%add(104, Panel 1, Lowest,  Abandoned (%),                                         fn(pct_A, 1),     ds=s3p1, wh=%str(tertile=1));
%add(105, Panel 1, Lowest,  Real time non-connection (%),                          fn(pct_B, 1),     ds=s3p1, wh=%str(tertile=1));
%add(111, Panel 1, Middle,  n,                                                    fi(n_practices),   ds=s3p1, wh=%str(tertile=2));
%add(112, Panel 1, Middle,  Online consultations per 1000 patients per month median, fn(med_oc, 0),    ds=s3p1, wh=%str(tertile=2));
%add(113, Panel 1, Middle,  Inbound calls per 1000 patients per month median,        fn(med_calls, 0), ds=s3p1, wh=%str(tertile=2));
%add(114, Panel 1, Middle,  Abandoned (%),                                         fn(pct_A, 1),     ds=s3p1, wh=%str(tertile=2));
%add(115, Panel 1, Middle,  Real time non-connection (%),                          fn(pct_B, 1),     ds=s3p1, wh=%str(tertile=2));
%add(121, Panel 1, Highest, n,                                                    fi(n_practices),   ds=s3p1, wh=%str(tertile=3));
%add(122, Panel 1, Highest, Online consultations per 1000 patients per month median, fn(med_oc, 0),    ds=s3p1, wh=%str(tertile=3));
%add(123, Panel 1, Highest, Inbound calls per 1000 patients per month median,        fn(med_calls, 0), ds=s3p1, wh=%str(tertile=3));
%add(124, Panel 1, Highest, Abandoned (%),                                         fn(pct_A, 1),     ds=s3p1, wh=%str(tertile=3));
%add(125, Panel 1, Highest, Real time non-connection (%),                          fn(pct_B, 1),     ds=s3p1, wh=%str(tertile=3));

%add(201, Panel 2, Inbound calls per 1000 registered patients, Change per doubling (95% CI),
     strip(fn(est, 1)) || '% (' || strip(fn(lo, 1)) || '% to ' || strip(fn(hi, 1)) || '%)', ds=s3p2, wh=%str(outcome='calls'));
%add(202, Panel 2, %str(Abandonment, percentage points),              Change per doubling (95% CI), ci(est, lo, hi, 2), ds=s3p2, wh=%str(outcome='ab'));
%add(203, Panel 2, %str(Real time non-connection, percentage points), Change per doubling (95% CI), ci(est, lo, hi, 2), ds=s3p2, wh=%str(outcome='rt'));

%add(301, Footnote, months of online consultation activity, , fi(months), ds=_set);
%add(302, Footnote, months by which the online consultation series is shorter than the telephony series, , fi(shorter), ds=_gap);
%add(303, Footnote, practice months, , fi(practice_months), ds=_set);
%add(304, Footnote, practices, , fi(practices), ds=_set);
%add(305, Footnote, practices with online consultation capability in at least one month, , pc(ever_analysis, 1), ds=S12c);
%add(306, Footnote, national median use January 2025 (per 1000 registered patients per month), , fn(med_first, 1), ds=S12m);
%add(307, Footnote, national median use June 2026 (per 1000 registered patients per month), , fn(med_last, 1), ds=S12m);
%add(308, Footnote, fold rise over the window, , strip(fn(fold, 1)) || '-fold', ds=S12m);
%add(309, Footnote, fewer calls per patient per doubling of use, , pc(-est, 1), ds=s3p2, wh=%str(outcome='calls'));
%add(310, Footnote, real time non-connection lower per doubling (percentage points), , fn(-est, 1), ds=s3p2, wh=%str(outcome='rt'));
%add(311, Footnote, real time non-connection level (call weighted%str(,) analysis set), , pc(rt_level, 0), ds=_set);
%add(312, Footnote, abandonment change per doubling (points), , fn(est, 2), ds=s3p2, wh=%str(outcome='ab'));
%add(313, Footnote, fold rise in use (repeated), , strip(fn(fold, 1)) || '-fold', ds=S12m);
%add(314, Footnote, median use most deprived decile (submissions per 1000 patients per month), , fn(med, 0), ds=_ocd, wh=%str(decile=1));
%add(315, Footnote, median use least deprived decile (submissions per 1000 patients per month), , fn(med, 0), ds=_ocd, wh=%str(decile=10));
%add(316, Footnote, practice months excluded whose supplier is No data, , fi(n_excl), ds=_ndn);
%add(317, Footnote, without No data practice months: inbound calls per 1000 registered patients, change per doubling (95% CI),
     strip(fn(est, 1)) || '% (' || strip(fn(lo, 1)) || '% to ' || strip(fn(hi, 1)) || '%)', ds=s3p2x, wh=%str(outcome='calls'));
%add(318, Footnote, without No data practice months: abandonment (percentage points), change per doubling (95% CI), ci(est, lo, hi, 2), ds=s3p2x, wh=%str(outcome='ab'));
%add(319, Footnote, without No data practice months: real time non-connection (percentage points), change per doubling (95% CI), ci(est, lo, hi, 2), ds=s3p2x, wh=%str(outcome='rt'));

%ms_write;

* PART 4. Supplementary tables S6 to S9 ;

/* MD_macros.sas - estimator and helper macros for the MD_ programs (TS6 to TS9).  INCLUDE ONLY.  ASCII only.
   Copied from the programs that produced the published numbers; only the log lines that printed sample sizes were removed.
     %fe_cr0   07_estimator.sas (log rate weighted least squares, practice month fixed effect, CR0 standard errors)
     %wls      the table program / check program 24 (weighted least squares with HC1 standard errors)
     %q7       check program 33 (linear interpolation percentiles, as pandas and numpy) */

/*---- %fe_cr0: copied from 07_estimator.sas --------------------------------------------------------------*/
%macro fe_cr0(data=, num=, den=, grp=, ref=, levels=, gid=, cid=,
              out=, label=);

    %local k kk i _DL _ML _SL _IN;
    %let k  = %sysfunc(countw(&levels));
    %let kk = %eval(&k * &k);
    %let _DL = ; %let _ML = ; %let _SL = ;
    %do i = 1 %to &k;
        %let _DL = &_DL d&i;
        %let _ML = &_ML md&i;
        %let _SL = &_SL s&i;
    %end;
    %let _IN = "&ref";
    %do i = 1 %to &k;
        %let _IN = &_IN, "%scan(&levels, &i)";
    %end;

    data _fe0;
        set &data;
        length _g $60 _c $60;
        _num = &num;
        _den = &den;
        if _den > 0 and _num > 0;
        if &grp in (&_IN);
        y  = log(_num / _den);
        w  = _den;
        _g = &gid;
        _c = &cid;
        array d{&k} &_DL;
        do _j = 1 to &k; d{_j} = 0; end;
        %do i = 1 %to &k;
            if &grp = "%scan(&levels, &i)" then d&i = 1;
        %end;
        keep y w _g _c &_DL;
    run;

    proc sql noprint;
        select count(*), count(distinct _c) into :_nobs trimmed, :_ncl trimmed
        from _fe0;
    quit;

    proc means data=_fe0 noprint nway;
        class _g;
        weight w;
        var y &_DL;
        output out=_gm(keep=_g my &_ML) mean(y &_DL) = my &_ML;
    run;
    proc sort data=_fe0; by _g; run;
    data _fe1;
        merge _fe0(in=a) _gm;
        by _g;
        array d{&k} &_DL;
        array m{&k} &_ML;
        y = y - my;
        do _j = 1 to &k; d{_j} = d{_j} - m{_j}; end;
        drop my &_ML _j;
    run;

    data _xtx(keep=a1-a&kk b1-b&k);
        set _fe1 end=_eof;
        array d{&k} &_DL;
        array A{&k,&k} a1-a&kk;
        array B{&k} b1-b&k;
        retain a1-a&kk b1-b&k 0;
        do _r = 1 to &k;
            B{_r} + w * d{_r} * y;
            do _c2 = 1 to &k;
                A{_r,_c2} + w * d{_r} * d{_c2};
            end;
        end;
        if _eof then output;
    run;

    data _beta(keep=beta1-beta&k) _ainv(keep=v1-v&kk);
        set _xtx;
        array A{&k,&k} a1-a&kk;
        array B{&k} b1-b&k;
        array Iv{&k,&k} _temporary_;
        array V{&k,&k} v1-v&kk;
        array bt{&k} beta1-beta&k;
        do r = 1 to &k;
            do c = 1 to &k; Iv{r,c} = (r = c); end;
        end;
        do p = 1 to &k;
            piv = A{p,p};
            if abs(piv) < 1e-10 then do;
                put "ERROR: singular design matrix in fe_cr0 (&label)";
                abort cancel;
            end;
            do c = 1 to &k;
                A{p,c}  = A{p,c}  / piv;
                Iv{p,c} = Iv{p,c} / piv;
            end;
            B{p} = B{p} / piv;
            do r = 1 to &k;
                if r ne p then do;
                    f = A{r,p};
                    do c = 1 to &k;
                        A{r,c}  = A{r,c}  - f * A{p,c};
                        Iv{r,c} = Iv{r,c} - f * Iv{p,c};
                    end;
                    B{r} = B{r} - f * B{p};
                end;
            end;
        end;
        do r = 1 to &k;
            bt{r} = B{r};
            do c = 1 to &k; V{r,c} = Iv{r,c}; end;
        end;
        output _beta;
        output _ainv;
    run;

    data _sc(keep=_c &_SL);
        if _n_ = 1 then set _beta;
        set _fe1;
        array d{&k} &_DL;
        array bt{&k} beta1-beta&k;
        array s{&k} &_SL;
        xb = 0;
        do _j = 1 to &k; xb = xb + bt{_j} * d{_j}; end;
        e = y - xb;
        do _j = 1 to &k; s{_j} = w * d{_j} * e; end;
    run;
    proc means data=_sc noprint nway;
        class _c;
        var &_SL;
        output out=_cs(keep=_c &_SL) sum= ;
    run;

    data _meat(keep=m1-m&kk);
        set _cs end=_eof;
        array s{&k} &_SL;
        array M{&k,&k} m1-m&kk;
        retain m1-m&kk 0;
        do _r = 1 to &k;
            do _c2 = 1 to &k; M{_r,_c2} + s{_r} * s{_c2}; end;
        end;
        if _eof then output;
    run;

    data &out;
        merge _ainv _meat _beta;
        length model $50 level $30;
        array V{&k,&k} v1-v&kk;
        array M{&k,&k} m1-m&kk;
        array bt{&k} beta1-beta&k;
        array T{&k,&k} _temporary_;
        do r = 1 to &k;
            do c = 1 to &k;
                t_ = 0;
                do q = 1 to &k; t_ = t_ + V{r,q} * M{q,c}; end;
                T{r,c} = t_;
            end;
        end;
        do r = 1 to &k;
            vr = 0;
            do q = 1 to &k; vr = vr + T{r,q} * V{q,r}; end;
            se      = sqrt(vr);
            model   = "&label";
            level   = scan("&levels", r);
            rr      = exp(bt{r});
            lcl     = exp(bt{r} - 1.96 * se);
            ucl     = exp(bt{r} + 1.96 * se);
            n_obs   = &_nobs;
            n_clust = &_ncl;
            output;
        end;
        keep model level rr lcl ucl se n_obs n_clust;
    run;

    proc datasets lib=work nolist;
        delete _fe0 _fe1 _gm _xtx _beta _ainv _sc _cs _meat;
    quit;
%mend fe_cr0;


/*---- %wls: copied from the table program (weighted least squares, HC1 standard errors) ---------------------*/
%macro wls(data=, y=, x=, w=, out=, tag=);
    %local k p i;
    %let k = %sysfunc(countw(&x)); %let p = %eval(&k + 1);
    data _w1;
        set &data;
        where &y ne . and &w ne . and &w > 0
        %do i = 1 %to &k; and %scan(&x, &i) ne . %end; ;
        keep &y &x &w;
    run;
    data _xtx(keep=i j v) _xty(keep=i v) _n(keep=n ybar sw);
        set _w1 end=eof;
        array xv{&p} _temporary_;
        array A{&p, &p} _temporary_;
        array b{&p} _temporary_;
        if _n_ = 1 then do;
            do i = 1 to &p; b{i} = 0; do j = 1 to &p; A{i, j} = 0; end; end;
        end;
        xv{1} = 1;
        %do i = 1 %to &k; xv{%eval(&i + 1)} = %scan(&x, &i); %end;
        do i = 1 to &p;
            b{i} = b{i} + &w * xv{i} * &y;
            do j = 1 to &p; A{i, j} = A{i, j} + &w * xv{i} * xv{j}; end;
        end;
        n + 1; sw + &w; swy + &w * &y;
        if eof then do;
            ybar = swy / sw;
            do i = 1 to &p;
                v = b{i}; output _xty;
                do j = 1 to &p; v = A{i, j}; output _xtx; end;
            end;
            output _n;
        end;
    run;
    data _inv(keep=i j v) _beta(keep=i beta);
        array A{&p, &p} _temporary_; array b{&p} _temporary_;
        array Inv{&p, &p} _temporary_;
        do until (e1); set _xtx end=e1; A{i, j} = v; end;
        do until (e2); set _xty end=e2; b{i} = v; end;
        do i = 1 to &p; do j = 1 to &p; Inv{i, j} = (i = j); end; end;
        do c = 1 to &p;
            piv = A{c, c};
            if abs(piv) < 1e-12 then do; put "ERROR: singular X'WX in wls &tag"; abort cancel; end;
            do j = 1 to &p; A{c, j} = A{c, j} / piv; Inv{c, j} = Inv{c, j} / piv; end;
            do r = 1 to &p; if r ne c then do;
                f = A{r, c};
                do j = 1 to &p; A{r, j} = A{r, j} - f * A{c, j}; Inv{r, j} = Inv{r, j} - f * Inv{c, j}; end;
            end; end;
        end;
        do i = 1 to &p;
            beta = 0; do j = 1 to &p; beta = beta + Inv{i, j} * b{j}; end; output _beta;
            do j = 1 to &p; v = Inv{i, j}; output _inv; end;
        end;
        stop;
    run;
    data _meat(keep=i j v) _fit(keep=r2);
        array xv{&p} _temporary_; array bt{&p} _temporary_;
        array M{&p, &p} _temporary_;
        if _n_ = 1 then do;
            do until (e1); set _beta end=e1; bt{i} = beta; end;
            set _n;
            do i = 1 to &p; do j = 1 to &p; M{i, j} = 0; end; end;
        end;
        set _w1 end=eof;
        xv{1} = 1;
        %do i = 1 %to &k; xv{%eval(&i + 1)} = %scan(&x, &i); %end;
        yhat = 0; do i = 1 to &p; yhat = yhat + bt{i} * xv{i}; end;
        e = &y - yhat;
        rss + &w * e * e; tss + &w * (&y - ybar) ** 2;
        do i = 1 to &p; do j = 1 to &p; M{i, j} = M{i, j} + (&w * e) ** 2 * xv{i} * xv{j}; end; end;
        if eof then do;
            r2 = 1 - rss / tss; output _fit;
            do i = 1 to &p; do j = 1 to &p; v = M{i, j}; output _meat; end; end;
        end;
    run;
    data &out(keep=tag var coef se t r2 n);
        length tag $40 var $32;
        array Inv{&p, &p} _temporary_; array M{&p, &p} _temporary_; array Vc{&p, &p} _temporary_;
        array bt{&p} _temporary_;
        do until (e1); set _inv end=e1; Inv{i, j} = v; end;
        do until (e2); set _meat end=e2; M{i, j} = v; end;
        do until (e3); set _beta end=e3; bt{i} = beta; end;
        set _n; set _fit;
        do i = 1 to &p; do j = 1 to &p;
            s = 0;
            do a = 1 to &p; do c = 1 to &p; s = s + Inv{i, a} * M{a, c} * Inv{c, j}; end; end;
            Vc{i, j} = s * n / (n - &p);
        end; end;
        tag = "&tag";
        var = 'Intercept'; coef = bt{1}; se = sqrt(Vc{1, 1}); t = coef / se; output;
        %do i = 1 %to &k;
            var = "%scan(&x, &i)"; coef = bt{%eval(&i + 1)}; se = sqrt(Vc{%eval(&i + 1), %eval(&i + 1)}); t = coef / se; output;
        %end;
        stop;
    run;
%mend wls;


/*---- %q7: copied from check program 33 (linear interpolation percentiles) -----------------*/
%macro q7(ds=, var=, plist=, out=);
    proc sort data=&ds(keep=&var where=(&var ne .)) out=_q7s; by &var; run;
    data &out;
        if 0 then set _q7s nobs=nn;
        length p q n 8;
        do _k = 1 to countw("&plist", ' ');
            p  = input(scan("&plist", _k, ' '), best32.);
            h  = (nn - 1) * p + 1;
            lo = floor(h); hi = min(lo + 1, nn);
            set _q7s point=lo; x1 = &var;
            set _q7s point=hi; x2 = &var;
            q = x1 + (h - lo) * (x2 - x1);
            n = nn;
            output;
        end;
        stop;
        keep p q n;
    run;
%mend q7;

* Table S6 (TS6_tableS6) ;
%fresh;

/* TS6_tableS6.sas - Table S6. Mechanism tests and checks of the callback record.
   Every number in table S6 and its two footnotes that is not printed elsewhere first, written to output\TS6_tableS6.txt.
   Derived from the table program, section TABLE S4 panels 1 to 4 (the program's 'TABLE S4' is the manuscript's
   table S6), and check program 33 part 13 (footnote numbers).
   Footnote numbers produced by other programs: 5049 (table 3), 7.1% of inbound calls (table S1 footnote).
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only).  ASCII only.
   Run: RUN_TS6_tableS6.bat */

%let PROG = TS6_tableS6;
* from MD_setup.sas ;
/* MD_setup.sas - common set-up for TS6_tableS6, TS7_tableS7, TS8_tableS8 and TS9_tableS9.
   INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder) and PROG (its own name) first.
   Does:  options; ODS output closed (programs compute quietly); 00_paths.sas (one folder up, libraries PERM = SAS_OUT_min100
          then SAS_OUT, PERMO = SAS_OUT, both read only); the estimator macros (MD_macros.sas); number formatting functions;
          the results table RES, the macro %md_add that puts one number into it, and %md_write that writes RES to
          output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;

/* the output file of this table, in the folder OUT (PART 0) */
%macro _md_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_md_dirs;

* input folders and libraries: set once in PART 1 ;
ods exclude all;
* MD_macros macros: defined in PART 4 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.mdfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if round(x, 10 ** (-d)) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 46 474) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
    /* P value: below 0.001 as <0.001, otherwise d decimals */
    function pv(p, d) $ 20;
        length s $20;
        if p < 0.001 then s = '<0.001';
        else s = fn(p, d);
        return(s);
    endsub;
run;
options cmplib=work.mdfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(24), part char(80), row char(200), col char(80), value char(120));
quit;

/* %md_add(order, exhibit, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro md_add(o, exh, part, row, col, val, ds=_one, wh=1);
    proc sql noprint;
        insert into RES (ord, exhibit, part, row, col, value)
        select &o, "&exh", "&part", "&row", "&col", put(&val, $120.) from &ds where &wh;
    quit;
    %if &sqlobs ne 1 %then %do; %put ERROR: md_add &o selected &sqlobs rows instead of one.; %abort cancel; %end;
%mend;

%macro md_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MD_setup.sas ;

%let T1MONTH = 202606;
%let STABLE  = 202510;
%let LEVELS  = rush_Mon midday late pre8;
%let E = Table S6;

/* XC: every practice in the stable window (the table program TABLE S4) */
proc sql;
    create table _evercd as
    select practice, (sum(CBT005) > 0) as ever_cb,
           sum(CBT005) / sum(CBT001)   as cb_int
    from perm.cell_daytime group by practice;
    create table _lsz as
    select practice_code as practice, max(list_size) as list_size
    from perm.practice_month where month = "&T1MONTH." group by practice_code;
    create table XC as
    select a.*, b.ever_cb, b.cb_int, c.list_size
    from perm.cell_daytime(where=(month >= "&STABLE.")) a
         inner join _evercd b on a.practice = b.practice
         left  join _lsz    c on a.practice = c.practice;
quit;

/* panel 1: by callback use */
data _s0; set XC; where ever_cb = 0; run;
data _s1; set XC; where ever_cb = 1; run;
%fe_cr0(data=_s0, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=c0, label=%str(no callback));
%fe_cr0(data=_s1, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=&LEVELS,
        gid=catx('|', practice, month), cid=practice, out=c1, label=%str(callback));
proc sql;
    create table _p1n as
    select (select count(distinct practice) from XC where ever_cb = 0) as n0,
           (select count(distinct practice) from XC where ever_cb = 1) as n1,
           (select count(distinct practice) from XC) as nall
    from _one;
quit;

/* panel 2: list size strata (median list size, June 2026) */
proc means data=_lsz noprint; var list_size; output out=_lmed median=lmed; run;
data _null_; set _lmed; call symputx('LMED', lmed); run;
%macro strat(cond, lab, out);
    data _sx; set XC; where &cond; run;
    %fe_cr0(data=_sx, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday,
            gid=catx('|', practice, month), cid=practice, out=&out, label=%str(&lab));
%mend;
%strat(%str(list_size >= &LMED and ever_cb = 0), large no callback, st1);
%strat(%str(list_size <  &LMED and ever_cb = 0), small no callback, st2);
%strat(%str(list_size >= &LMED and ever_cb = 1), large callback,    st3);
%strat(%str(list_size <  &LMED and ever_cb = 1), small callback,    st4);

/* panel 3: callback intensity tertiles among callback practices */
proc sql;
    create table _cbi as select distinct practice, cb_int from XC where ever_cb = 1;
quit;
proc rank data=_cbi out=_cbi groups=3; var cb_int; ranks cbter; run;
proc sql;
    create table XC3 as
    select a.*, b.cbter from XC a inner join _cbi b on a.practice = b.practice;
quit;
%macro cbter(t, lab, out);
    data _sy; set XC3; where cbter = &t; run;
    %fe_cr0(data=_sy, num=CBT004, den=CBT001, grp=cell, ref=rush_TueFri, levels=rush_Mon midday,
            gid=catx('|', practice, month), cid=practice, out=&out, label=%str(&lab));
%mend;
%cbter(0, lowest, ct1); %cbter(1, middle, ct2); %cbter(2, highest, ct3);

/* panel 4: published fulfilment ratio, practice months with 100 or more requests */
data _ful;
    set perm.practice_month;
    where cbt005_cb_requested >= 100;
    ratio = cbt006_cb_made / cbt005_cb_requested;
    if      ratio <  0.95 then bord = 1;
    else if ratio <  1.00 then bord = 2;
    else if ratio =  1.00 then bord = 3;
    else                       bord = 4;
    keep ratio bord cbt005_cb_requested cbt006_cb_made;
run;
proc freq data=_ful noprint; tables bord / out=s4p4; run;

/* footnote, panel 4: median and 10th centile (linear interpolation), correlation (check program 33 part 13) */
%q7(ds=_ful, var=ratio, plist=0.1 0.5, out=_q13);
proc corr data=_ful pearson noprint outp=_c13; var cbt005_cb_requested cbt006_cb_made; run;
data _c13; set _c13; where _TYPE_ = 'CORR' and _NAME_ = 'cbt005_cb_requested'; r = cbt006_cb_made; keep r; run;
proc sql;
    create table _f4 as
    select (select count(*) from _ful) as n, (select q from _q13 where p = 0.5) as med,
           (select q from _q13 where p = 0.1) as p10, (select r from _c13) as r
    from _one;
quit;

/* footnote, panels 1 to 3: share of participating practices recording at least one callback request each month
   (check program 33 part 13) */
proc sql;
    create table _s13m as
    select month, 100 * mean(coalesce(cbt005_cb_requested, 0) > 0) as pct_req
    from perm.practice_month where cbt_observed = 1 group by month;
    create table _s13 as select min(pct_req) as min_pct, max(pct_req) as max_pct from _s13m;
quit;

/* results */
%md_add(1,  &E, Panel 1, header, Practices without callback (n), fi(n0), ds=_p1n);
%md_add(2,  &E, Panel 1, header, Callback practices (n), fi(n1), ds=_p1n);
%md_add(3,  &E, Panel 1, Monday rush 08:00 to 10:00, Practices without callback, ci(rr, lcl, ucl, 2), ds=c0, wh=%str(level='rush_Mon'));
%md_add(4,  &E, Panel 1, Monday rush 08:00 to 10:00, Callback practices,         ci(rr, lcl, ucl, 2), ds=c1, wh=%str(level='rush_Mon'));
%md_add(5,  &E, Panel 1, Midday 10:00 to 16:00, Practices without callback,      ci(rr, lcl, ucl, 2), ds=c0, wh=%str(level='midday'));
%md_add(6,  &E, Panel 1, Midday 10:00 to 16:00, Callback practices,              ci(rr, lcl, ucl, 2), ds=c1, wh=%str(level='midday'));
%md_add(7,  &E, Panel 1, Late afternoon 16:00 to 18:30, Practices without callback, ci(rr, lcl, ucl, 2), ds=c0, wh=%str(level='late'));
%md_add(8,  &E, Panel 1, Late afternoon 16:00 to 18:30, Callback practices,         ci(rr, lcl, ucl, 2), ds=c1, wh=%str(level='late'));
%md_add(9,  &E, Panel 2, %str(Large practices, no callback), Monday rush RR (95% CI), ci(rr, lcl, ucl, 2), ds=st1, wh=%str(level='rush_Mon'));
%md_add(10, &E, Panel 2, %str(Large practices, no callback), Midday RR (95% CI),      ci(rr, lcl, ucl, 2), ds=st1, wh=%str(level='midday'));
%md_add(11, &E, Panel 2, %str(Small practices, no callback), Monday rush RR (95% CI), ci(rr, lcl, ucl, 2), ds=st2, wh=%str(level='rush_Mon'));
%md_add(12, &E, Panel 2, %str(Small practices, no callback), Midday RR (95% CI),      ci(rr, lcl, ucl, 2), ds=st2, wh=%str(level='midday'));
%md_add(13, &E, Panel 2, %str(Large practices, callback), Monday rush RR (95% CI),    ci(rr, lcl, ucl, 2), ds=st3, wh=%str(level='rush_Mon'));
%md_add(14, &E, Panel 2, %str(Large practices, callback), Midday RR (95% CI),         ci(rr, lcl, ucl, 2), ds=st3, wh=%str(level='midday'));
%md_add(15, &E, Panel 2, %str(Small practices, callback), Monday rush RR (95% CI),    ci(rr, lcl, ucl, 2), ds=st4, wh=%str(level='rush_Mon'));
%md_add(16, &E, Panel 2, %str(Small practices, callback), Midday RR (95% CI),         ci(rr, lcl, ucl, 2), ds=st4, wh=%str(level='midday'));
%md_add(17, &E, Panel 3, Lowest tertile,  Monday rush RR (95% CI), ci(rr, lcl, ucl, 2), ds=ct1, wh=%str(level='rush_Mon'));
%md_add(18, &E, Panel 3, Lowest tertile,  Midday RR (95% CI),      ci(rr, lcl, ucl, 2), ds=ct1, wh=%str(level='midday'));
%md_add(19, &E, Panel 3, Middle tertile,  Monday rush RR (95% CI), ci(rr, lcl, ucl, 2), ds=ct2, wh=%str(level='rush_Mon'));
%md_add(20, &E, Panel 3, Middle tertile,  Midday RR (95% CI),      ci(rr, lcl, ucl, 2), ds=ct2, wh=%str(level='midday'));
%md_add(21, &E, Panel 3, Highest tertile, Monday rush RR (95% CI), ci(rr, lcl, ucl, 2), ds=ct3, wh=%str(level='rush_Mon'));
%md_add(22, &E, Panel 3, Highest tertile, Midday RR (95% CI),      ci(rr, lcl, ucl, 2), ds=ct3, wh=%str(level='midday'));
%md_add(23, &E, Panel 4, <0.95,         % of practice months, fn(percent, 1), ds=s4p4, wh=%str(bord=1));
%md_add(24, &E, Panel 4, 0.95 to <1.00, % of practice months, fn(percent, 1), ds=s4p4, wh=%str(bord=2));
%md_add(25, &E, Panel 4, Exactly 1.00,  % of practice months, fn(percent, 1), ds=s4p4, wh=%str(bord=3));
%md_add(26, &E, Panel 4, >1.00,         % of practice months, fn(percent, 1), ds=s4p4, wh=%str(bord=4));
%md_add(27, &E, footnote, practices with calls in the window in both groups of panel 1, n, fi(nall), ds=_p1n);
%md_add(28, &E, footnote, practices recording at least one callback request each month, %str(% of participating practices, lowest to highest month), cat(strip(fn(min_pct, 0)), '% to ', strip(fn(max_pct, 0)), '%'), ds=_s13);
%md_add(29, &E, footnote, panel 4 practice months with at least 100 callback requests, n, fi(n), ds=_f4);
%md_add(30, &E, footnote, panel 4 fulfilment ratio median, value, fn(med, 2), ds=_f4);
%md_add(31, &E, footnote, panel 4 fulfilment ratio 10th centile, value, fn(p10, 4), ds=_f4);
%md_add(32, &E, footnote, panel 4 callbacks requested v callbacks made, correlation r, fn(r, 4), ds=_f4);

%md_write;

* Table S7 (TS7_tableS7) ;
%fresh;

/* TS7_tableS7.sas - Table S7. Practices sharing a postcode: within-site comparison against the GP Patient Survey, and what
   explains the differences in abandonment.
   Every number in table S7 and its footnote that is not printed elsewhere first, written to output\TS7_tableS7.txt.
   Derived from:
     the table program, section TABLE S5 panel 1 and panel 2 with its footnote numbers (the program's 'TABLE S5'
       is the manuscript's table S7): samples, within-site correlations, within-site R2 of the three component model,
       panel 2 standardised coefficients, median and widest gap, two practice sites, single network;
     check program 24 part 2b: panel 1 coefficients with a site fixed effect and standard errors clustered by site
       (PROC SURVEYREG), unweighted (table) and weighted by respondents (footnote);
     check program 31 part 4b: panel 2 confidence intervals clustered by site.
   Number produced by another program: 4.2% (main text; the same value is the panel 2 R2 printed here).
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only).  ASCII only.
   Run: RUN_TS7_tableS7.bat */

%let PROG = TS7_tableS7;
* from MD_setup.sas ;
/* MD_setup.sas - common set-up for TS6_tableS6, TS7_tableS7, TS8_tableS8 and TS9_tableS9.
   INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder) and PROG (its own name) first.
   Does:  options; ODS output closed (programs compute quietly); 00_paths.sas (one folder up, libraries PERM = SAS_OUT_min100
          then SAS_OUT, PERMO = SAS_OUT, both read only); the estimator macros (MD_macros.sas); number formatting functions;
          the results table RES, the macro %md_add that puts one number into it, and %md_write that writes RES to
          output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;

/* the output file of this table, in the folder OUT (PART 0) */
%macro _md_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_md_dirs;

* input folders and libraries: set once in PART 1 ;
ods exclude all;
* MD_macros macros: defined in PART 4 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.mdfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if round(x, 10 ** (-d)) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 46 474) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
    /* P value: below 0.001 as <0.001, otherwise d decimals */
    function pv(p, d) $ 20;
        length s $20;
        if p < 0.001 then s = '<0.001';
        else s = fn(p, d);
        return(s);
    endsub;
run;
options cmplib=work.mdfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(24), part char(80), row char(200), col char(80), value char(120));
quit;

/* %md_add(order, exhibit, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro md_add(o, exh, part, row, col, val, ds=_one, wh=1);
    proc sql noprint;
        insert into RES (ord, exhibit, part, row, col, value)
        select &o, "&exh", "&part", "&row", "&col", put(&val, $120.) from &ds where &wh;
    quit;
    %if &sqlobs ne 1 %then %do; %put ERROR: md_add &o selected &sqlobs rows instead of one.; %abort cancel; %end;
%mend;

%macro md_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MD_setup.sas ;

%let STABLE = 202510;
%let E = Table S7;

/* LK: the survey link (the table program) */
data LK;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
run;

/*---- panel 1: within shared postcode sites, January to March 2026 ----------------------------------------*/
data _site;
    set LK;
    where A_w26 ne . and ease_2026 ne . and postcode ne '';
    pc = upcase(compress(postcode));
run;
proc sql;
    create table _site2 as
    select a.*, b.nsite,
           a.ease_2026 - b.mY as y_dm, a.A_w26 - b.mA as A_dm, a.W_w26 - b.mW as W_dm,
           a.cb_w26 - b.mcb as cb_dm, a.menu_w26 - b.mmenu as menu_dm
    from _site a inner join
         (select pc, count(*) as nsite, mean(ease_2026) as mY, mean(A_w26) as mA,
                 mean(W_w26) as mW, mean(cb_w26) as mcb, mean(menu_w26) as mmenu
          from _site group by pc having count(*) >= 2) b
    on a.pc = b.pc;
    create table s5p1r as
    select count(*) as n_practices, count(distinct pc) as n_sites,
           sum(y_dm * A_dm) / sqrt(sum(y_dm * y_dm) * sum(A_dm * A_dm)) as r_A,
           sum(y_dm * W_dm) / sqrt(sum(y_dm * y_dm) * sum(W_dm * W_dm)) as r_W
    from _site2;
quit;
data _site2; set _site2; one = 1; run;
/* within-site R2 of the unweighted three component model (the table program %wls on site-demeaned values) */
%wls(data=_site2, y=y_dm, x=A_dm cb_dm menu_dm, w=one, out=s5p1d, tag=within site);
/* coefficients: site fixed effect, standard errors clustered by site (check program 24 part 2b) */
proc surveyreg data=_site2;
    class pc;
    model ease_2026 = A_w26 cb_w26 menu_w26 pc / solution clparm;
    cluster pc;
    ods output ParameterEstimates=_s2u;
run;
proc surveyreg data=_site2;
    class pc;
    weight n_eval_2026;
    model ease_2026 = A_w26 cb_w26 menu_w26 pc / solution clparm;
    cluster pc;
    ods output ParameterEstimates=_s2w;
run;

/*---- panel 2: what explains abandonment differences inside a site, October 2025 to June 2026 --------------*/
proc sql;
    create table _pc9 as
    select practice_code, max(postcode) as postcode,
           sum(cbt004_missed) / sum(cbt001_inbound)    as ab_rate,
           sum(cbt005_cb_requested) / sum(cbt001_inbound) as cb_int,
           mean(list_size)                             as list_size,
           1000 * mean(gp_fte_qualified) / mean(list_size)  as gp_per1000,
           1000 * mean(reception_fte)    / mean(list_size)  as rec_per1000,
           1000 * (sum(cbt001_inbound) / count(distinct month)) / mean(list_size) as calls_per1000
    from perm.practice_month
    where month >= "&STABLE." and cbt_observed = 1 and cbt001_inbound > 0 and list_size > 0
    group by practice_code
    having sum(cbt001_inbound) > 0;
quit;
/* practices without GP or reception FTE are dropped before sites are formed (the table program fix) */
data _pc9;
    set _pc9;
    pc = upcase(compress(postcode));
    if pc ne '' and gp_per1000 ne . and rec_per1000 ne .;
run;
proc sql;
    create table _pc9d as
    select a.*,
           a.ab_rate      - b.m1 as z_y,
           a.cb_int       - b.m2 as z_cb,
           a.gp_per1000   - b.m3 as z_gp,
           a.list_size    - b.m4 as z_ls,
           a.rec_per1000  - b.m5 as z_rec,
           a.calls_per1000- b.m6 as z_cl
    from _pc9 a inner join
         (select pc, count(*) as nsite, mean(ab_rate) as m1, mean(cb_int) as m2,
                 mean(gp_per1000) as m3, mean(list_size) as m4,
                 mean(rec_per1000) as m5, mean(calls_per1000) as m6
          from _pc9 group by pc having count(*) >= 2) b
    on a.pc = b.pc;
quit;
proc means data=_pc9d noprint;
    var z_y z_cb z_gp z_ls z_rec z_cl;
    output out=_sd std = s_y s_cb s_gp s_ls s_rec s_cl;
run;
data _pc9s;
    if _n_ = 1 then set _sd;
    set _pc9d;
    sy = z_y / s_y; scb = z_cb / s_cb; sgp = z_gp / s_gp;
    sls = z_ls / s_ls; srec = z_rec / s_rec; scl = z_cl / s_cl;
    one = 1;
run;
proc sql;
    create table s5p2r as
    select count(*) as n_practices, count(distinct pc) as n_sites,
           sum(sy * scb) / sqrt(sum(sy * sy) * sum(scb * scb)) as r_cb,
           sum(sy * sgp) / sqrt(sum(sy * sy) * sum(sgp * sgp)) as r_gp,
           sum(sy * sls) / sqrt(sum(sy * sy) * sum(sls * sls)) as r_ls,
           sum(sy * srec)/ sqrt(sum(sy * sy) * sum(srec * srec)) as r_rec,
           sum(sy * scl) / sqrt(sum(sy * sy) * sum(scl * scl)) as r_cl
    from _pc9s;
quit;
/* standardised coefficients with site clustered standard errors (check program 31 part 4b) */
proc surveyreg data=_pc9s;
    cluster pc;
    model sy = scb sgp sls srec scl / clparm;
    ods output ParameterEstimates=_p2e FitStatistics=_p2f;
run;
data _p2r2; set _p2f; where Label1 = 'R-Square'; r2 = nValue1; keep r2; run;

/* footnote numbers for panel 2, same sites (the table program TABLE S5 PANEL 2 - footnote numbers) */
proc sql;
    create table _pairs as
    select a.pc, count(*) as nprac,
           100 * (max(a.ab_rate) - min(a.ab_rate)) as gap_pp,
           100 * max(a.ab_rate) as worst_pct,
           100 * min(a.ab_rate) as best_pct
    from _pc9d a group by a.pc;
quit;
proc means data=_pairs noprint; var gap_pp; output out=_gapq median=med_gap max=max_gap; run;
proc sql;
    create table _widest as
    select best_pct, worst_pct from _pairs having gap_pp = max(gap_pp);
    create table _two as select pc from _pc9d group by pc having count(*) = 2;
    create table _twod as
    select a.* from _pc9d a inner join _two b on a.pc = b.pc;
quit;
proc sort data=_twod; by pc calls_per1000; run;
data _cmp;
    set _twod; by pc;
    retain _ab1 _cl1;
    if first.pc then do; _ab1 = ab_rate; _cl1 = calls_per1000; end;
    else if last.pc then do;
        if calls_per1000 ne _cl1 then do;
            busier_worse = (ab_rate > _ab1);
            output;
        end;
    end;
    keep pc busier_worse;
run;
proc sql;
    create table _busy as
    select count(*) as n, 100 * mean(busier_worse) as pct,
           100 * (mean(busier_worse) - 1.96 * sqrt(mean(busier_worse) * (1 - mean(busier_worse)) / count(*))) as lo,
           100 * (mean(busier_worse) + 1.96 * sqrt(mean(busier_worse) * (1 - mean(busier_worse)) / count(*))) as hi
    from _cmp;
    /* shared sites lying in a single primary care network */
    create table _pcn as
    select a.pc, count(distinct b.pcn_code) as npcn, count(*) as nprac,
           sum(b.pcn_code = '' or b.pcn_code is null) as nmiss
    from _pc9d a left join perm.ext_link b on a.practice_code = b.practice_code
    group by a.pc;
    create table _pcn1 as
    select 100 * mean(npcn = 1) as pct_one_pcn from _pcn where nmiss = 0;
quit;

/* results */
%md_add(1,  &E, Panel 1, header, practices, fi(n_practices), ds=s5p1r);
%md_add(2,  &E, Panel 1, header, sites, fi(n_sites), ds=s5p1r);
%md_add(3,  &E, Panel 1, Abandoned, Within-site correlation with ease, fn(r_A, 2), ds=s5p1r);
%md_add(4,  &E, Panel 1, Abandoned, Change in ease per percentage point (95% CI), ci(Estimate, LowerCL, UpperCL, 2), ds=_s2u, wh=%str(Parameter='A_w26'));
%md_add(5,  &E, Panel 1, Callback diverted, Change in ease per percentage point (95% CI), ci(Estimate, LowerCL, UpperCL, 2), ds=_s2u, wh=%str(Parameter='cb_w26'));
%md_add(6,  &E, Panel 1, Menu ended, Change in ease per percentage point (95% CI), ci(Estimate, LowerCL, UpperCL, 2), ds=_s2u, wh=%str(Parameter='menu_w26'));
%md_add(7,  &E, Panel 1, Total non-connection, Within-site correlation with ease, fn(r_W, 2), ds=s5p1r);
%md_add(8,  &E, Panel 2, Callback intensity (callbacks/inbound calls), Correlation with abandonment, fn(r_cb, 2), ds=s5p2r);
%md_add(9,  &E, Panel 2, Callback intensity (callbacks/inbound calls), Standardised coefficient (95% CI), ci(Estimate, LowerCL, UpperCL, 3), ds=_p2e, wh=%str(Parameter='scb'));
%md_add(10, &E, Panel 2, GP FTE per 1000 patients, Correlation with abandonment, fn(r_gp, 2), ds=s5p2r);
%md_add(11, &E, Panel 2, GP FTE per 1000 patients, Standardised coefficient (95% CI), ci(Estimate, LowerCL, UpperCL, 3), ds=_p2e, wh=%str(Parameter='sgp'));
%md_add(12, &E, Panel 2, Registered list size, Correlation with abandonment, fn(r_ls, 2), ds=s5p2r);
%md_add(13, &E, Panel 2, Registered list size, Standardised coefficient (95% CI), ci(Estimate, LowerCL, UpperCL, 3), ds=_p2e, wh=%str(Parameter='sls'));
%md_add(14, &E, Panel 2, Reception FTE per 1000 patients, Correlation with abandonment, fn(r_rec, 2), ds=s5p2r);
%md_add(15, &E, Panel 2, Reception FTE per 1000 patients, Standardised coefficient (95% CI), ci(Estimate, LowerCL, UpperCL, 3), ds=_p2e, wh=%str(Parameter='srec'));
%md_add(16, &E, Panel 2, Inbound calls per 1000 patients, Correlation with abandonment, fn(r_cl, 2), ds=s5p2r);
%md_add(17, &E, Panel 2, Inbound calls per 1000 patients, Standardised coefficient (95% CI), ci(Estimate, LowerCL, UpperCL, 3), ds=_p2e, wh=%str(Parameter='scl'));
%md_add(18, &E, Panel 2, All five characteristics together, R2, fn(r2, 3), ds=_p2r2);
%md_add(19, &E, footnote, panel 1 three component model (unweighted), within-site R2, fn(r2, 2), ds=s5p1d, wh=%str(var='A_dm'));
%md_add(20, &E, footnote, panel 1 weighted by respondents, abandoned (95% CI), ci(Estimate, LowerCL, UpperCL, 2), ds=_s2w, wh=%str(Parameter='A_w26'));
%md_add(21, &E, footnote, panel 1 weighted by respondents, callback diverted (95% CI), ci(Estimate, LowerCL, UpperCL, 2), ds=_s2w, wh=%str(Parameter='cb_w26'));
%md_add(22, &E, footnote, panel 1 weighted by respondents, menu ended (95% CI), ci(Estimate, LowerCL, UpperCL, 2), ds=_s2w, wh=%str(Parameter='menu_w26'));
%md_add(23, &E, footnote, panel 2 sample, practices, fi(n_practices), ds=s5p2r);
%md_add(24, &E, footnote, panel 2 sample, sites, fi(n_sites), ds=s5p2r);
%md_add(25, &E, footnote, median within-site gap in abandonment, percentage points, fn(med_gap, 1), ds=_gapq);
%md_add(26, &E, footnote, widest within-site gap, abandonment of the two practices (%), cat(strip(fn(best_pct, 0)), '% v ', strip(fn(worst_pct, 0)), '%'), ds=_widest);
%md_add(27, &E, footnote, sites shared by two practices, n, fi(n), ds=_busy);
%md_add(28, &E, footnote, sites shared by two practices, busier practice the worse one (95% CI), cat(strip(fn(pct, 0)), '% (', strip(fn(lo, 0)), '% to ', strip(fn(hi, 0)), '%)'), ds=_busy);
%md_add(29, &E, footnote, shared sites within a single primary care network, % of sites (printed as four in five), pc(pct_one_pcn, 0), ds=_pcn1);

%md_write;

* Table S8 (TS8_tableS8) ;
%fresh;

/* TS8_tableS8.sas - Table S8. Recorded callback fulfilment shortfall by patient weighted deprivation decile.
   Every number in table S8 and its footnote, written to output\TS8_tableS8.txt.
   Derived from the table program, section TABLE S6 (the program's 'TABLE S6' is the manuscript's table S8):
   practice months with at least 100 callback requests, decile recorded on the practice month itself.
   The footnote's "0.16% to 0.63% in the others" repeats the cells of deciles 4 and 9 and is not printed again.
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only).  ASCII only.
   Run: RUN_TS8_tableS8.bat */

%let PROG = TS8_tableS8;
* from MD_setup.sas ;
/* MD_setup.sas - common set-up for TS6_tableS6, TS7_tableS7, TS8_tableS8 and TS9_tableS9.
   INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder) and PROG (its own name) first.
   Does:  options; ODS output closed (programs compute quietly); 00_paths.sas (one folder up, libraries PERM = SAS_OUT_min100
          then SAS_OUT, PERMO = SAS_OUT, both read only); the estimator macros (MD_macros.sas); number formatting functions;
          the results table RES, the macro %md_add that puts one number into it, and %md_write that writes RES to
          output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;

/* the output file of this table, in the folder OUT (PART 0) */
%macro _md_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_md_dirs;

* input folders and libraries: set once in PART 1 ;
ods exclude all;
* MD_macros macros: defined in PART 4 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.mdfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if round(x, 10 ** (-d)) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 46 474) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
    /* P value: below 0.001 as <0.001, otherwise d decimals */
    function pv(p, d) $ 20;
        length s $20;
        if p < 0.001 then s = '<0.001';
        else s = fn(p, d);
        return(s);
    endsub;
run;
options cmplib=work.mdfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(24), part char(80), row char(200), col char(80), value char(120));
quit;

/* %md_add(order, exhibit, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro md_add(o, exh, part, row, col, val, ds=_one, wh=1);
    proc sql noprint;
        insert into RES (ord, exhibit, part, row, col, value)
        select &o, "&exh", "&part", "&row", "&col", put(&val, $120.) from &ds where &wh;
    quit;
    %if &sqlobs ne 1 %then %do; %put ERROR: md_add &o selected &sqlobs rows instead of one.; %abort cancel; %end;
%mend;

%macro md_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MD_setup.sas ;

%let E = Table S8;

data _s6;
    set perm.practice_month;
    where cbt005_cb_requested >= 100 and not missing(pw_imd_decile_1poorest);
    decile = pw_imd_decile_1poorest;
    req    = cbt005_cb_requested;
    made   = cbt006_cb_made;
    short  = max(req - made, 0);
    ident  = (made = req);
    keep practice_code month decile req made short ident;
run;
proc sql;
    create table s6 as
    select decile, count(*) as pm,
           100 * sum(made)  / sum(req) as dialled,
           100 * mean(ident)           as exact,
           100 * sum(short) / sum(req) as shortfall
    from _s6 group by decile;
    create table _pmr as select min(pm) as lo, max(pm) as hi from s6;
quit;

%macro rows;
    %local d lab;
    %do d = 1 %to 10;
        %if &d = 1 %then %let lab = 1 (most deprived);
        %else %if &d = 10 %then %let lab = 10 (least deprived);
        %else %let lab = &d;
        %md_add(%eval(2 * &d - 1), &E, decile, &lab, Callbacks dialled / requested (%), fn(dialled, 2), ds=s6, wh=%str(decile=&d));
        %md_add(%eval(2 * &d),     &E, decile, &lab, %str(Shortfall, % of requests),     fn(shortfall, 2), ds=s6, wh=%str(decile=&d));
    %end;
%mend;
%rows;
%md_add(21, &E, footnote, practice months in each decile, smallest to largest, cat(strip(fi(lo)), ' to ', strip(fi(hi))), ds=_pmr);
%md_add(22, &E, footnote, dialled count equal to requested count, most deprived decile (% of months), pc(exact, 1), ds=s6, wh=%str(decile=1));
%md_add(23, &E, footnote, dialled count equal to requested count, least deprived decile (% of months), pc(exact, 1), ds=s6, wh=%str(decile=10));

%md_write;

* Table S9 (TS9_tableS9) ;
%fresh;

/* TS9_tableS9.sas - Table S9. Patient reported ease of phone contact by year and by when the practice entered the
   telephony collection.
   Every number in table S9, written to output\TS9_tableS9.txt (the table has no footnote).
   Derived from the table program, section TABLE S7 (the program's 'TABLE S7' is the manuscript's table S9):
   practices with survey results in 2024 and 2026, unweighted means of practice shares, cohort by first month in the
   collection.
   Reads PERM (SAS_OUT_min100 then SAS_OUT, read only).  ASCII only.
   Run: RUN_TS9_tableS9.bat */

%let PROG = TS9_tableS9;
* from MD_setup.sas ;
/* MD_setup.sas - common set-up for TS6_tableS6, TS7_tableS7, TS8_tableS8 and TS9_tableS9.
   INCLUDE ONLY.  ASCII only.
   The calling program sets CODEDIR (its own folder) and PROG (its own name) first.
   Does:  options; ODS output closed (programs compute quietly); 00_paths.sas (one folder up, libraries PERM = SAS_OUT_min100
          then SAS_OUT, PERMO = SAS_OUT, both read only); the estimator macros (MD_macros.sas); number formatting functions;
          the results table RES, the macro %md_add that puts one number into it, and %md_write that writes RES to
          output\<PROG>.txt (one line per number: exhibit | part | row | column | value). */

options validvarname=v7 nodate nonumber compress=yes nofmterr;
ods exclude all;

/* the output file of this table, in the folder OUT (PART 0) */
%macro _md_dirs;
    %global OUTFILE;
    %let OUTFILE = &OUT.\&PROG..txt;
%mend;
%_md_dirs;

* input folders and libraries: set once in PART 1 ;
ods exclude all;
* MD_macros macros: defined in PART 4 ;

/* number formatting, as printed in the paper */
proc fcmp outlib=work.mdfunc.fmt;
    /* x to d decimals; a value that rounds to zero is printed without a minus sign */
    function fn(x, d) $ 40;
        length s $40 fm $12;
        if missing(x) then s = '.';
        else do;
            fm = cats('32.', d);
            s  = strip(putn(x, fm));
            if substr(s, 1, 1) = '-' and compress(s, '-0.') = '' then s = substr(s, 2);
        end;
        return(s);
    endsub;
    /* the same with a plus sign on positive values */
    function sg(x, d) $ 40;
        length s $40;
        s = fn(x, d);
        if round(x, 10 ** (-d)) > 0 then s = cats('+', s);
        return(s);
    endsub;
    /* estimate (lower to upper) */
    function ci(e, l, h, d) $ 120;
        length s $120;
        s = strip(fn(e, d)) || ' (' || strip(fn(l, d)) || ' to ' || strip(fn(h, d)) || ')';
        return(s);
    endsub;
    /* lower to upper only */
    function rng(l, h, d) $ 80;
        length s $80;
        s = strip(fn(l, d)) || ' to ' || strip(fn(h, d));
        return(s);
    endsub;
    /* percentage */
    function pc(x, d) $ 40;
        length s $40;
        s = strip(fn(x, d)) || '%';
        return(s);
    endsub;
    /* whole number; five digits or more take a space as thousands separator (BMJ style, 46 474) */
    function fi(x) $ 40;
        length s $40;
        if missing(x) then s = '.';
        else do;
            s = strip(put(round(x, 1), comma32.));
            if abs(x) >= 10000 then s = translate(s, ' ', ',');
            else s = compress(s, ',');
        end;
        return(s);
    endsub;
    /* P value: below 0.001 as <0.001, otherwise d decimals */
    function pv(p, d) $ 20;
        length s $20;
        if p < 0.001 then s = '<0.001';
        else s = fn(p, d);
        return(s);
    endsub;
run;
options cmplib=work.mdfunc;

data _one; x = 1; run;

proc sql;
    create table RES (ord num, exhibit char(24), part char(80), row char(200), col char(80), value char(120));
quit;

/* %md_add(order, exhibit, part, row, column, value expression, ds=, wh=)
   Labels containing a comma go inside %str().  The value expression may use the functions above and any
   column of DS; WH must select exactly one row. */
%macro md_add(o, exh, part, row, col, val, ds=_one, wh=1);
    proc sql noprint;
        insert into RES (ord, exhibit, part, row, col, value)
        select &o, "&exh", "&part", "&row", "&col", put(&val, $120.) from &ds where &wh;
    quit;
    %if &sqlobs ne 1 %then %do; %put ERROR: md_add &o selected &sqlobs rows instead of one.; %abort cancel; %end;
%mend;

%macro md_write;
    proc sort data=RES; by ord; run;
    data _null_;
        set RES;
        file "&OUTFILE" lrecl=2000;
        length line $1600;
        line = catx(' | ', exhibit, part, row, col, value);
        put line;
    run;
    %put NOTE: &PROG - results written to the output folder;
%mend;
* end of MD_setup.sas ;

%let E = Table S9;

data _trend;
    set perm.ext_link;
    where ease_2024 ne . and ease_2026 ne .;
    if      first_month = ''        then ord = 4;
    else if first_month <= '202412' then ord = 1;
    else if first_month <= '202509' then ord = 2;
    else                                 ord = 3;
run;
proc sql;
    create table s7 as
    select ord, count(*) as n,
           mean(ease_2024) as e2024, mean(ease_2025) as e2025, mean(ease_2026) as e2026,
           mean(ease_2026) - mean(ease_2024) as change
    from _trend group by ord
    union all
    select 5, count(*),
           mean(ease_2024), mean(ease_2025), mean(ease_2026), mean(ease_2026) - mean(ease_2024)
    from _trend;
quit;

%macro rows;
    %local o lab b;
    %do o = 1 %to 5;
        %if &o = 1 %then %let lab = Entered October to December 2024;
        %else %if &o = 2 %then %let lab = Entered January to September 2025;
        %else %if &o = 3 %then %let lab = Entered October 2025 or later;
        %else %if &o = 4 %then %let lab = Never in the collection;
        %else %let lab = All practices surveyed in all three years;
        %let b = %eval(10 * &o);
        %md_add(%eval(&b + 1), &E, row, &lab, n,    fi(n),       ds=s7, wh=%str(ord=&o));
        %md_add(%eval(&b + 2), &E, row, &lab, 2024, fn(e2024, 1), ds=s7, wh=%str(ord=&o));
        %md_add(%eval(&b + 3), &E, row, &lab, 2025, fn(e2025, 1), ds=s7, wh=%str(ord=&o));
        %md_add(%eval(&b + 4), &E, row, &lab, 2026, fn(e2026, 1), ds=s7, wh=%str(ord=&o));
        %md_add(%eval(&b + 5), &E, row, &lab, Change 2024 to 2026 (percentage points), sg(change, 1), ds=s7, wh=%str(ord=&o));
    %end;
%mend;
%rows;

%md_write;

* Table S11 (TS11_tableS11) ;
%fresh;

/* TS11_tableS11.sas - Table S11. What the five definitions of a failed call do and do not capture: variation between practices in
   appointment timing, in waiting time thought about right, and in what patients did after failed contact, explained by each definition;
   and, in its footnote, the June 2026 national count of calls answered and the share answered within 2 minutes.
   Writes output\TS11_tableS11.txt (one line per number: exhibit | part | row | column | value).
   Reads PERM.EXT_LINK (read only), the appointment files of January to March 2025 and 2026 (folder GPAD DB under ROOT), the GP Patient
   Survey practice files of 2025 and 2026 (GPPS25, GPPS26, found in PART 1) and the June 2026 telephony durations files (CBTDIR).
   Weighted R2 = squared weighted Pearson correlation; 2000 bootstrap resamples of practices (seed 20261107), one set for the appointment
   and waiting criteria and one for the actions after failed contact. ASCII only. */

%let PROG = TS11_tableS11;
%let NBOOT = 2000;
%let SEED = 20261107;
options validvarname=v7 nodate nonumber nofmterr;

/* failed-call measures */
data LK;
    set perm.ext_link;
    W_w25 = A_w25 + cb_w25 + menu_w25;
    W_w26 = A_w26 + cb_w26 + menu_w26;
    keep practice_code A_w25 B_w25 As_w25 Bs_w25 W_w25 A_w26 B_w26 As_w26 Bs_w26 W_w26 list_w25 list_w26
         ease_2025 ease_2026 n_eval_2025 n_eval_2026;
run;

/* appointments, January to March of each survey year */
%macro rdgp(file, wave);
    data _g;
        length mon $12 gp $10 a3-a8 $200 hcp $40 a10 $80 a11 $120 bk $40 st $40;
        infile "&ROOT.\GPAD DB\&file" dsd truncover firstobs=2 lrecl=4096 encoding='utf-8';
        input mon $ gp $ a3 $ a4 $ a5 $ a6 $ a7 $ a8 $ hcp $ a10 $ a11 $ bk $ cnt st $;
        bk = compbl(strip(bk));
        gpf = (strip(hcp) = 'GP');
        same  = cnt * (gpf and bk = 'Same Day');
        p15   = cnt * (gpf and bk in ('15 to 21 Days', '22 to 28 Days', 'More than 28 Days'));
        known = cnt * (gpf and bk ne 'Unknown / Data Issue');
        keep mon gp cnt same p15 known;
    run;
    proc sql;
        create table _s as select "&wave" as wave length=3, gp, mon, sum(cnt) as appt, sum(same) as gp_same,
               sum(p15) as gp_15p, sum(known) as gp_known
        from _g group by gp, mon;
    quit;
    proc append base=GPADM data=_s force; run;
%mend;
%rdgp(Practice_Level_Crosstab_Jan_25.csv, w25);
%rdgp(Practice_Level_Crosstab_Feb_25.csv, w25);
%rdgp(Practice_Level_Crosstab_Mar_25.csv, w25);
%rdgp(Practice_Level_Crosstab_Jan_26.csv, w26);
%rdgp(Practice_Level_Crosstab_Feb_26.csv, w26);
%rdgp(Practice_Level_Crosstab_London_East_South_Mar_26.csv, w26);
%rdgp(Practice_Level_Crosstab_Midlands_North_Mar_26.csv, w26);
proc sql;
    create table GPADW as
    select wave, gp as practice_code length=10, count(distinct mon) as n_mon, sum(appt) as appt, sum(gp_same) as gp_same,
           sum(gp_15p) as gp_15p, sum(gp_known) as gp_known
    from (select wave, gp, mon, sum(appt) as appt, sum(gp_same) as gp_same, sum(gp_15p) as gp_15p, sum(gp_known) as gp_known
          from GPADM group by wave, gp, mon)
    group by wave, gp;
quit;

/* survey columns located by name; the header line is longer than 32767 characters, so it is read one field per observation */
%macro hdr(file);
    data _hdr;
        infile "&file" obs=1 lrecl=2000000 dsd encoding='utf-8';
        length h $200;
        input h :$200. @@;
        i + 1;
        h = lowcase(compress(h, '"'));
    run;
%mend;
%macro col(name, mvar);
    %global &mvar; %let &mvar = ;
    data _null_; set _hdr; if h = "&name" then call symputx("&mvar", i); run;
%mend;
%macro rdgpps(file, wave);
    %global ncol ipc;
    %hdr(&file);
    data _null_; set _hdr end=last; if index(h, 'ad_practicecode') then call symputx('ipc', i); if last then call symputx('ncol', i); run;
    %col(lastgpapptlengthgap_1.pct, i1); %col(lastgpapptlengthgap_2.pct, i2); %col(lastgpapptlengthgap_3.pct, i3);
    %col(lastgpapptlengthgap_4.pct, i4); %col(lastgpapptlengthgap_5.pct, i5); %col(lastgpapptwait.pcteval, iwait);
    %col(lastgpapptlengthgap.baseevaluw, ib20); %col(lastgpapptwait.baseevaluw, ib21);
    %col(gpcontactunsuccessful_5.pct, i111); %col(gpcontactunsuccessful_8.pct, iae); %col(gpcontactunsuccessful_1.pct, iagain);
    %col(gpcontactunsuccessful.basefullw, ib15); %col(gpcontactoverall.basefullw, ib16); %col(gpcontactoverall.basefulluw, ib16u);
    data GP_&wave;
        infile "&file" dsd firstobs=2 lrecl=2000000 truncover encoding='utf-8';
        length f1-f&ncol $60 practice_code $10;
        input (f1-f&ncol) (:$60.);
        array f{*} f1-f&ncol;
        practice_code = strip(f{&ipc});
        p1 = input(f{&i1}, ?? best32.); p2 = input(f{&i2}, ?? best32.); p3 = input(f{&i3}, ?? best32.);
        p4 = input(f{&i4}, ?? best32.); p5 = input(f{&i5}, ?? best32.);
        wait = input(f{&iwait}, ?? best32.); w_C4 = input(f{&ib20}, ?? best32.); w_C5 = input(f{&ib21}, ?? best32.);
        p111 = input(f{&i111}, ?? best32.); pae = input(f{&iae}, ?? best32.); pagain = input(f{&iagain}, ?? best32.);
        b15 = input(f{&ib15}, ?? best32.); b16 = input(f{&ib16}, ?? best32.); w16 = input(f{&ib16u}, ?? best32.);
        array v{*} p1-p5 wait w_C4 w_C5 p111 pae pagain b15 b16 w16;
        do j = 1 to dim(v); if v{j} < 0 then v{j} = .; end;    /* -97 = suppressed */
        if n(of p1-p5) = 5 then do;
            den = sum(of p1-p5);
            if den > 0 then C4 = 100 * (p1 + p2) / den;
        end;
        if wait ne . then C5 = 100 * wait;
        if b16 > 0 and b15 ne . then do;
            sh = b15 / b16;
            if p111 ne . then C6 = 100 * p111 * sh;
            if pae ne . then C7 = 100 * pae * sh;
            if pagain ne . then C8 = 100 * pagain * sh;
        end;
        keep practice_code C4 C5 C6 C7 C8 w_C4 w_C5 w16;
    run;
%mend;
%rdgpps(&GPPS25, w25);
%rdgpps(&GPPS26, w26);

/* one row per practice, criterion and wave; set 1 = appointment and waiting criteria (with ease, so that the bootstrap draws are
   those of the analysis program), set 2 = actions after failed contact. The weight is called wt: SAS names are not case sensitive. */
%macro build(tag, yr);
    proc sql;
        create table B_&tag as
        select k.practice_code, k.A_&tag as A, k.B_&tag as B, k.As_&tag as As, k.Bs_&tag as Bs, k.W_&tag as W, k.list_&tag as list,
               k.ease_&yr as ease, k.n_eval_&yr as n_eval, g.n_mon, g.appt, g.gp_same, g.gp_15p, g.gp_known,
               s.C4, s.C5, s.C6, s.C7, s.C8, s.w_C4, s.w_C5, s.w16
        from LK k left join GPADW(where=(wave="&tag")) g on k.practice_code = g.practice_code
                  left join GP_&tag s on k.practice_code = s.practice_code
        where n(k.A_&tag, k.B_&tag, k.As_&tag, k.Bs_&tag, k.W_&tag, k.list_&tag) = 6;
    quit;
    data S1_&tag(keep=wave crit practice_code y wt A B As Bs W) S2_&tag(keep=wave crit practice_code y wt A B As Bs W);
        length wave $4 crit $32;
        set B_&tag;
        wave = "&yr";
        if gp_known > 0 then do; C1 = 100 * gp_same / gp_known; C2 = 100 * gp_15p / gp_known; end;
        if n_mon > 0 and list > 0 then C3 = 1000 * appt / n_mon / list;
        crit = 'ease';                        y = ease; wt = n_eval; if y ne . and wt > 0 then output S1_&tag;
        crit = 'C1_gp_same_day_pct';          y = C1;   wt = list;   if y ne . and wt > 0 and n_mon = 3 then output S1_&tag;
        crit = 'C2_gp_15plus_days_pct';       y = C2;   wt = list;   if y ne . and wt > 0 and n_mon = 3 then output S1_&tag;
        crit = 'C3_appts_per_1000';           y = C3;   wt = list;   if y ne . and wt > 0 and n_mon = 3 then output S1_&tag;
        crit = 'C4_q20_same_or_next_day_pct'; y = C4;   wt = w_C4;   if y ne . and wt > 0 then output S1_&tag;
        crit = 'C5_q21_wait_about_right_pct'; y = C5;   wt = w_C5;   if y ne . and wt > 0 then output S1_&tag;
        wt = w16;
        crit = 'C6_failed_then_nhs111_pct';      y = C6; if y ne . and wt > 0 then output S2_&tag;
        crit = 'C7_failed_then_ae_pct';          y = C7; if y ne . and wt > 0 then output S2_&tag;
        crit = 'C8_failed_then_tried_again_pct'; y = C8; if y ne . and wt > 0 then output S2_&tag;
    run;
%mend;
%build(w25, 2025);
%build(w26, 2026);

%macro r2set(k);
    data AL&k; set S&k._w25 S&k._w26; run;
    proc sort data=AL&k; by wave crit practice_code; run;
    proc corr data=AL&k outp=_pc noprint; by wave crit; weight wt; var A B As Bs W; with y; run;
    data PT&k;
        set _pc(where=(_type_ in ('CORR', 'N')));
        by wave crit;
        retain n;
        if _type_ = 'N' then n = A;
        if _type_ = 'CORR' then do;
            array d{5} A B As Bs W;
            array r{5} R2_A R2_B R2_As R2_Bs R2_W;
            array s{5} sg_A sg_B sg_As sg_Bs sg_W;
            do j = 1 to 5; r{j} = d{j} ** 2; s{j} = sign(d{j}); end;
            output;
        end;
        keep wave crit n R2_A R2_B R2_As R2_Bs R2_W sg_A sg_B sg_As sg_Bs sg_W;
    run;
    proc surveyselect data=AL&k out=_bs method=urs samprate=1 reps=&NBOOT seed=&SEED outhits noprint; strata wave crit; run;
    proc sort data=_bs; by wave crit replicate; run;
    proc corr data=_bs outp=_bc noprint; by wave crit replicate; weight wt; var A B As Bs W; with y; run;
    data BR;
        set _bc(where=(_type_ = 'CORR'));
        R2_A = A ** 2; R2_B = B ** 2; R2_As = As ** 2; R2_Bs = Bs ** 2; R2_W = W ** 2;
        dB = R2_B - R2_A; dAs = R2_As - R2_A; dBs = R2_Bs - R2_A; dW = R2_W - R2_A;
        keep wave crit replicate R2_A R2_B R2_As R2_Bs R2_W dB dAs dBs dW;
    run;
    proc univariate data=BR noprint;
        by wave crit;
        var R2_A R2_B R2_As R2_Bs R2_W dB dAs dBs dW;
        output out=CI&k pctlpts=2.5 97.5 pctlpre=R2_A_ R2_B_ R2_As_ R2_Bs_ R2_W_ dB_ dAs_ dBs_ dW_;
    run;
%mend;
%r2set(1);
%r2set(2);

/* June 2026 answered calls by waiting time */
%macro rddur(rg);
    data _d;
        length dt $10 a2-a6 $40 ind $10 dur $12;
        infile "&CBTDIR.\Cloud Based Telephony By Durations - June 2026_&rg..csv" dsd truncover firstobs=2 lrecl=4096 encoding='utf-8';
        input dt $ a2 $ a3 $ a4 $ a5 $ a6 $ ind $ dur $ val;
        if strip(ind) = 'CBT003';
        keep dur val;
    run;
    proc append base=DUR data=_d force; run;
%mend;
%rddur(Unmapped); %rddur(Y56); %rddur(Y58); %rddur(Y59); %rddur(Y60); %rddur(Y61); %rddur(Y62); %rddur(Y63);
proc sql;
    create table DURS as
    select sum(val) as answered, sum(val * (strip(dur) in ('0', '1_30', '31_60', '61_90', '91_120'))) as within2
    from DUR;
quit;

/* output: panels A to H as printed (R2 and differences to 3 decimals; ease is not part of table S11) */
data PTCI; merge PT1 CI1 PT2 CI2; by wave crit; if crit ne 'ease'; run;
data _null_;
    set PTCI;
    file "&OUT.\&PROG..txt" lrecl=400;
    length panel $8 def $40 s $60;
    select (crit);
        when ('C1_gp_same_day_pct')             panel = 'Panel A';
        when ('C2_gp_15plus_days_pct')          panel = 'Panel B';
        when ('C3_appts_per_1000')              panel = 'Panel C';
        when ('C4_q20_same_or_next_day_pct')    panel = 'Panel D';
        when ('C5_q21_wait_about_right_pct')    panel = 'Panel E';
        when ('C8_failed_then_tried_again_pct') panel = 'Panel F';
        when ('C6_failed_then_nhs111_pct')      panel = 'Panel G';
        when ('C7_failed_then_ae_pct')          panel = 'Panel H';
        otherwise panel = '';
    end;
    array r{5} R2_A R2_B R2_As R2_Bs R2_W;
    array g{5} sg_A sg_B sg_As sg_Bs sg_W;
    array lo{5} R2_A_2_5 R2_B_2_5 R2_As_2_5 R2_Bs_2_5 R2_W_2_5;
    array hi{5} R2_A_97_5 R2_B_97_5 R2_As_97_5 R2_Bs_97_5 R2_W_97_5;
    array dlo{5} _temporary_;
    array dhi{5} _temporary_;
    dlo{2} = dB_2_5;  dhi{2} = dB_97_5;  dlo{3} = dAs_2_5; dhi{3} = dAs_97_5;
    dlo{4} = dBs_2_5; dhi{4} = dBs_97_5; dlo{5} = dW_2_5;  dhi{5} = dW_97_5;
    put 'Table S11 | ' panel ' | practices | ' wave ' | ' n;
    do j = 1 to 5;
        def = scan('Abandonment|Real time non-connection|Queue restricted abandonment|Queue restricted non-connection|Total non-connection', j, '|');
        s = cat(strip(put(r{j}, 8.3)), ' (', strip(put(lo{j}, 8.3)), ' to ', strip(put(hi{j}, 8.3)), ')');
        put 'Table S11 | ' panel ' | ' def ' | R2 ' wave ' | ' s;
        if j > 1 then do;
            s = cat(strip(put(r{j} - r{1}, 8.3)), ' (', strip(put(dlo{j}, 8.3)), ' to ', strip(put(dhi{j}, 8.3)), ')');
            put 'Table S11 | ' panel ' | ' def ' | Difference from abandonment ' wave ' | ' s;
        end;
        put 'Table S11 | ' panel ' | ' def ' | Direction ' wave ' | ' g{j} 2.;
    end;
run;
data _null_;
    set DURS;
    file "&OUT.\&PROG..txt" mod lrecl=400;
    s = put(answered, 12.); put 'Table S11 | Footnote | June 2026 | Calls answered by practice staff | ' s;
    s = put(within2 / answered * 100, 8.1); put 'Table S11 | Footnote | June 2026 | Answered within 2 min, % | ' s;
run;
%put NOTE: &PROG - results written to the output folder;


* Table S12 (TS12_tableS12) ;
%fresh;

/* TS12_tableS12.sas - Table S12. Waiting times by time of day that NHS England published for each practice (all calls, core hours, 8am to 10am,
   10am to 6:30pm), January to March 2025 and 2026, against reported ease of phone contact in the GP Patient Survey of the same year, with abandonment
   and total non-connection on the same practices; and, in the footnote, the same comparison for June 2026 and the national monthly percentages.
   Writes output\TS12_tableS12.txt (one line per number: exhibit | row | column | value).
   Reads PERM.EXT_LINK (read only), NHS England's Calls Answered Metric zip files (folder CBTADIR, found in PART 1; read inside the zip, not unpacked)
   and the June 2026 telephony durations files (CBTDIR).
   Sample per year: reported ease and its weight present, all six measures present. Weighted R2 = squared weighted Pearson correlation, weight = unweighted
   respondents to the question, as table 2; 2000 bootstrap resamples of practices within each year (seed 20261109). ASCII only. */

%let PROG = TS12_tableS12;
%let NBOOT = 2000;
%let SEED = 20261109;
options validvarname=v7 nodate nonumber nofmterr;

/* answered calls by practice, wait band and period. The Unassigned rows (shared accounts) stay in for the national percentages and drop out at the link.
   The zip is first copied to WORK: the ZIP access method cannot open a path holding Korean characters. */
%macro rdans(zipfile, member, mon);
    %local r rg wk;
    %let wk = %sysfunc(pathname(work))\_cba.zip;
    filename _s "&CBTADIR.\&zipfile" recfm=n;
    filename _t "&wk" recfm=n;
    data _null_;
        rc = fcopy('_s', '_t');
        if rc ne 0 then do; put 'ERROR: cannot copy the answered calls zip file.'; abort cancel; end;
    run;
    filename _s clear;
    filename _t clear;
    %do r = 1 %to 8;
        %let rg = %scan(Unmapped Y56 Y58 Y59 Y60 Y61 Y62 Y63, &r);
        filename _z zip "&wk" member="Cloud Based Telephony Calls Answered Metric - &member._&rg..csv";
        data _d;
            length practice $10 indicator $10 band $12 cat $14;
            infile _z dsd truncover firstobs=2 lrecl=2048;
            input dt :$10. region_code :$10. icb :$20. sub_icb :$20. pcn :$20. practice $ indicator $ band $ cat $ value;
            if missing(value) then value = 0;
            if indicator ne 'CBT003' then delete;
            over = (band in ('121_180', '181_240', '241_300', '>300'));
            core = (cat in ('Core_8_10', 'Core_10_1830'));
            rush = (cat = 'Core_8_10');
            late = (cat = 'Core_10_1830');
            keep practice over core rush late value;
        run;
        proc sql;
            create table _a as
            select "&mon" as mon length=7, practice,
                   sum(value) as n_all, sum(value * over) as o_all,
                   sum(value * core) as n_core, sum(value * over * core) as o_core,
                   sum(value * rush) as n_rush, sum(value * over * rush) as o_rush,
                   sum(value * late) as n_late, sum(value * over * late) as o_late
            from _d group by practice;
        quit;
        proc append base=ANS data=_a force; run;
        filename _z clear;
    %end;
%mend;
%rdans(cloud-based-telephony-calls-answered-metric---january-2025.zip,  January 2025,  2025-01);
%rdans(cloud-based-telephony-calls-answered-metric---february-2025.zip, February 2025, 2025-02);
%rdans(cloud-based-telephony-calls-answered-metric---march-2025.zip,    March 2025,    2025-03);
%rdans(cloud-based-telephony-calls-answered-metric---january-2026.zip,  January 2026,  2026-01);
%rdans(cloud-based-telephony-calls-answered-metric---february-2026.zip, February 2026, 2026-02);
%rdans(cloud-based-telephony-calls-answered-metric---march-2026.zip,    March 2026,    2026-03);
%rdans(Cloud Based Telephony Calls Answered Metric - June 2026.zip,     June 2026,     2026-06);

proc sql;
    /* national percentages answered within 2 min, by month */
    create table NATM as
    select mon, sum(n_all) as n_all, sum(n_core) as n_core, sum(n_rush) as n_rush,
           100 * (1 - sum(o_all) / sum(n_all)) as p_all, 100 * (1 - sum(o_core) / sum(n_core)) as p_core, 100 * (1 - sum(o_rush) / sum(n_rush)) as p_rush
    from ANS group by mon order by mon;
    /* practice totals: survey windows and June */
    create table ANSP as
    select case when mon in ('2025-01', '2025-02', '2025-03') then '2025' when mon in ('2026-01', '2026-02', '2026-03') then '2026' else 'June' end as wave length=4,
           practice as practice_code length=10,
           sum(n_all) as n_all, sum(o_all) as o_all, sum(n_core) as n_core, sum(o_core) as o_core, sum(n_rush) as n_rush, sum(o_rush) as o_rush, sum(n_late) as n_late, sum(o_late) as o_late
    from ANS group by calculated wave, practice;
quit;
data ANSP;
    set ANSP;
    if n_all > 0 then w_all = 100 * o_all / n_all;
    if n_core > 0 then w_core = 100 * o_core / n_core;
    if n_rush > 0 then w_rush = 100 * o_rush / n_rush;
    if n_late > 0 then w_late = 100 * o_late / n_late;
    keep wave practice_code n_rush w_all w_core w_rush w_late;
run;

/* one row per practice and survey year */
%macro bld(yr, ext);
    proc sql;
        create table S_&yr as
        select "&yr" as wave length=4, k.practice_code, k.ease_&yr as y, k.n_eval_&yr as wt, q.w_all, q.w_core, q.w_rush, q.w_late,
               k.A_&ext as A, k.A_&ext + k.cb_&ext + k.menu_&ext as W, q.n_rush
        from perm.ext_link k left join ANSP(where=(wave = "&yr")) q on k.practice_code = q.practice_code;
    quit;
%mend;
%bld(2025, w25);
%bld(2026, w26);
data AL;
    set S_2025 S_2026;
    if y ne . and wt > 0 and n(w_all, w_core, w_rush, w_late, A, W) = 6;
run;
proc sort data=AL; by wave practice_code; run;

%let MEAS = w_all w_core w_rush w_late A W;

/* point estimates, weighted means, practices */
proc corr data=AL outp=_pc noprint; by wave; weight wt; var &MEAS; with y; run;
data PT;
    set _pc(where=(_type_ = 'CORR'));
    array m{6} &MEAS;
    array r{6} r1-r6;
    array g{6} g1-g6;
    do j = 1 to 6; r{j} = m{j} ** 2; g{j} = sign(m{j}); end;
    keep wave r1-r6 g1-g6;
run;
data MN;
    set _pc(where=(_type_ = 'MEAN'));
    array m{6} &MEAS;
    array u{6} u1-u6;
    do j = 1 to 6; u{j} = m{j}; end;
    keep wave u1-u6;
run;
proc sql;
    create table NP as select wave, count(*) as n from AL group by wave order by wave;
    create table NP50 as select wave, count(*) as n50 from AL where n_rush >= 50 group by wave order by wave;
quit;

/* at least 50 answered calls between 8am and 10am over the three months */
proc corr data=AL(where=(n_rush >= 50)) outp=_pc50 noprint; by wave; weight wt; var w_all w_rush A; with y; run;
data P50;
    set _pc50(where=(_type_ = 'CORR'));
    s_all = w_all ** 2; s_rush = w_rush ** 2; s_A = A ** 2;
    keep wave s_all s_rush s_A;
run;

/* bootstrap within year: differences are from the waiting time between 8am and 10am */
proc surveyselect data=AL out=_bs method=urs samprate=1 reps=&NBOOT seed=&SEED outhits noprint; strata wave; run;
proc sort data=_bs; by wave replicate; run;
proc corr data=_bs outp=_bc noprint; by wave replicate; weight wt; var &MEAS; with y; run;
data BR;
    set _bc(where=(_type_ = 'CORR'));
    array m{6} &MEAS;
    array r{6} r1-r6;
    array d{6} d1-d6;
    do j = 1 to 6; r{j} = m{j} ** 2; end;
    do j = 1 to 6; d{j} = r{j} - r{3}; end;
    keep wave replicate r1-r6 d1 d2 d4-d6;
run;
proc univariate data=BR noprint;
    by wave;
    var r1-r6 d1 d2 d4-d6;
    output out=CI pctlpts=2.5 97.5 pctlpre=r1_ r2_ r3_ r4_ r5_ r6_ d1_ d2_ d4_ d5_ d6_;
run;

/* June 2026, after the fieldwork and the supplier's correction: abandonment and total non-connection from the durations files */
%macro rddur;
    %local r rg;
    %do r = 1 %to 7;
        %let rg = %scan(Y56 Y58 Y59 Y60 Y61 Y62 Y63, &r);
        data _d;
            length practice $10 indicator $10 dur $12;
            infile "&CBTDIR.\Cloud Based Telephony By Durations - June 2026_&rg..csv" dsd truncover firstobs=2 lrecl=2048;
            input dt : yymmdd10. region_code : $10. icb : $20. sub_icb : $20. pcn : $20. practice $ indicator $ dur $ value;
            if missing(value) then value = 0;
            if practice = 'Unassigned' then delete;
            keep practice indicator value;
        run;
        proc sql;
            create table _a as
            select practice as practice_code length=10,
                   sum(case when indicator = 'CBT001' then value else 0 end) as d_inb,
                   sum(case when indicator = 'CBT002' then value else 0 end) as d_ivr,
                   sum(case when indicator = 'CBT004' then value else 0 end) as d_mis,
                   sum(case when indicator = 'CBT005' then value else 0 end) as d_cb
            from _d group by practice;
        quit;
        proc append base=DURJ data=_a force; run;
    %end;
%mend;
%rddur;
proc sql;
    create table DJ as
    select practice_code, sum(d_inb) as d_inb, sum(d_ivr) as d_ivr, sum(d_mis) as d_mis, sum(d_cb) as d_cb
    from DURJ group by practice_code;
    create table AJ as
    select k.practice_code, k.ease_2026 as y, k.n_eval_2026 as wt, q.w_all, q.w_core, q.w_rush, j.d_inb,
           case when j.d_inb > 0 then 100 * j.d_mis / j.d_inb else . end as A_jun,
           case when j.d_inb > 0 then 100 * (j.d_mis + j.d_ivr + j.d_cb) / j.d_inb else . end as W_jun
    from perm.ext_link k
         left join ANSP(where=(wave = 'June')) q on k.practice_code = q.practice_code
         left join DJ j on k.practice_code = j.practice_code;
quit;
data AJ; set AJ; if y ne . and wt > 0 and d_inb >= 100 and n(w_all, w_core, w_rush, A_jun, W_jun) = 5; run;
proc corr data=AJ outp=_pj noprint; weight wt; var w_all w_core w_rush A_jun W_jun; with y; run;
data PJ;
    set _pj(where=(_type_ = 'CORR'));
    j_all = w_all ** 2; j_core = w_core ** 2; j_rush = w_rush ** 2; j_A = A_jun ** 2; j_W = W_jun ** 2;
    keep j_all j_core j_rush j_A j_W;
run;
proc sql noprint; select count(*) into :NJ trimmed from AJ; quit;

/* output, formatted as printed (R2 and differences to 3 decimals) */
data _null_;
    merge PT MN CI NP NP50 P50;
    by wave;
    file "&OUT.\&PROG..txt" lrecl=400;
    length row $70 s $60;
    array r{6} r1-r6;
    array g{6} g1-g6;
    array u{6} u1-u6;
    array lo{6} r1_2_5 r2_2_5 r3_2_5 r4_2_5 r5_2_5 r6_2_5;
    array hi{6} r1_97_5 r2_97_5 r3_97_5 r4_97_5 r5_97_5 r6_97_5;
    array dl{6} d1_2_5 d2_2_5 _x1 d4_2_5 d5_2_5 d6_2_5;
    array dh{6} d1_97_5 d2_97_5 _x2 d4_97_5 d5_97_5 d6_97_5;
    put 'Table S12 | Practices | ' wave ' | ' n;
    do j = 1 to 6;
        row = scan('Answered calls waiting more than 2 min, all calls|Answered calls waiting more than 2 min, core hours|'
                || 'Answered calls waiting more than 2 min, 8am to 10am|Answered calls waiting more than 2 min, 10am to 6:30pm|Abandonment|Total non-connection', j, '|');
        s = put(u{j}, 8.1); put 'Table S12 | ' row ' | Weighted mean ' wave ' | ' s;
        s = cat(strip(put(r{j}, 8.3)), ' (', strip(put(lo{j}, 8.3)), ' to ', strip(put(hi{j}, 8.3)), ')');
        put 'Table S12 | ' row ' | R2 ' wave ' | ' s;
        if j ne 3 then do;
            s = cat(strip(put(r{j} - r{3}, 8.3)), ' (', strip(put(dl{j}, 8.3)), ' to ', strip(put(dh{j}, 8.3)), ')');
            put 'Table S12 | ' row ' | Difference from 8am to 10am ' wave ' | ' s;
        end;
        put 'Table S12 | ' row ' | Direction ' wave ' | ' g{j} 2.;
    end;
    put 'Table S12 | Footnote | Practices with at least 50 answered calls between 8am and 10am ' wave ' | ' n50;
    s = put(s_all, 8.3);  put 'Table S12 | Footnote | Same, R2 all calls ' wave ' | ' s;
    s = put(s_rush, 8.3); put 'Table S12 | Footnote | Same, R2 8am to 10am ' wave ' | ' s;
    s = put(s_A, 8.3);    put 'Table S12 | Footnote | Same, R2 abandonment ' wave ' | ' s;
run;
data _null_;
    set PJ;
    file "&OUT.\&PROG..txt" mod lrecl=400;
    length s $60;
    put "Table S12 | Footnote | June 2026, practices | &NJ";
    s = put(j_all, 8.3);  put 'Table S12 | Footnote | June 2026, R2 all calls | ' s;
    s = put(j_core, 8.3); put 'Table S12 | Footnote | June 2026, R2 core hours | ' s;
    s = put(j_rush, 8.3); put 'Table S12 | Footnote | June 2026, R2 8am to 10am | ' s;
    s = put(j_A, 8.3);    put 'Table S12 | Footnote | June 2026, R2 abandonment | ' s;
    s = put(j_W, 8.3);    put 'Table S12 | Footnote | June 2026, R2 total non-connection | ' s;
run;
data _null_;
    set NATM;
    file "&OUT.\&PROG..txt" mod lrecl=400;
    length s $60;
    s = put(n_core, 12.); put 'Table S12 | Footnote | National ' mon ', answered in core hours | ' s;
    s = put(p_core, 8.1); put 'Table S12 | Footnote | National ' mon ', within 2 min in core hours, % | ' s;
    s = put(n_rush, 12.); put 'Table S12 | Footnote | National ' mon ', answered between 8am and 10am | ' s;
    s = put(p_rush, 8.1); put 'Table S12 | Footnote | National ' mon ', within 2 min between 8am and 10am, % | ' s;
run;
%put NOTE: &PROG - results written to the output folder;

* end of paper0_tables.sas ;
