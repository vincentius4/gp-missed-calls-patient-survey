# Code for the tables and figures of: Do missed calls to general practices reflect patients' reported ease of phone contact?

A national observational study linking NHS England's cloud based telephony data to the GP Patient Survey.
Haedong Kim, Sihyun Oh, Hajae Jeon, Jaeyong Shin (Department of Preventive Medicine, Yonsei University College of Medicine, Seoul).
Licence: MIT (see `LICENSE`).

| File | Produces |
|---|---|
| `paper0_tables.sas` | Tables 1 to 3 and supplementary tables S1 to S9, S11 and S12 with their footnotes (table S10 repeats table 2 from the same output); one text file per table in `output/` |
| `paper0_figures.py` | Figures 1 to 3 and supplementary figures S1 to S9, in `figures/` |

**Inputs.** The analysis datasets that the authors built from openly published files (folders `SAS_OUT` and
`SAS_OUT_min100`) and a few published files read directly; the published files are those in the paper's reference
list. The programs that build the analysis datasets, and the datasets themselves, are not included.

**How to run.** SAS: set `ROOT` in PART 0 of `paper0_tables.sas` (or the environment variable `PAPER0_ROOT`) to the
folder holding `SAS_OUT`, `SAS_OUT_min100` and the published files (including the GP Patient Survey practice results for 2025
and 2026, the appointment files of January to March 2025 and 2026 in a folder `GPAD DB`, and NHS England's Calls Answered Metric zip files
for January to March 2025 and 2026 and June 2026, kept as published), and run the whole file (about 20 minutes).
Python: `python paper0_figures.py` with `PAPER0_ROOT` set.

**Software.** SAS 9.4 for Windows (Base SAS, SAS/STAT; TS1M7). Python 3.13.15 with matplotlib 3.11.2, numpy 2.5.4
and pandas 3.1.0. With these versions the tables and figures are reproduced exactly; random steps use fixed seeds.
Supplementary figure S9 was revised on 10 November 2026 (values inside the bars) and drawn with matplotlib 3.11.1,
numpy 2.5.1 and pandas 3.0.5.
