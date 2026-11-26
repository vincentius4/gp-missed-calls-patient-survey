# Data and code for: Missed Calls to General Practices and Patients' Reported Ease of Phone Contact in England: National Observational Study

Haedong Kim, Sihyun Oh, Hajae Jeon, Jaeyong Shin (Department of Preventive Medicine, Yonsei University College of Medicine, Seoul).
Licence for the code: MIT (see `LICENSE`).

The two programs reproduce the tables and figures of the paper, with the paper's numbering, from the data files in this repository alone, and write nothing else.

## Contents

| Path | What it is |
|---|---|
| `paper0_tables.sas` | Writes `Table1.txt` to `Table4.txt` (main article) and `TableS1.txt` to `TableS5.txt` (Multimedia Appendix 1) to the folder `output`: every value printed in the body of each table, one line per value (`table \| part \| row \| column \| value`) |
| `paper0_figures.py` | Draws `Figure1.png` to `Figure3.png` (main article) and `FigureS1.png` to `FigureS3.png` (Multimedia Appendix 1) in the folder `figures` |
| `data/<name>.csv.gz` | The practice-level analysis datasets that the programs read: gzip-compressed CSV files (comma separated, one header line, an empty field is a missing value) |
| `data/data_dictionary.csv` | For every dataset: number of rows, and for every variable its position, name, type, length, and a description |

### Datasets

| File | Rows | Unit | Read for |
|---|---|---|---|
| `practice_month.csv.gz` | 130,386 | practice and month: list size and demographics, deprivation, the published telephony counts (CBT001 to CBT006), workforce, online consultation rate, location | tables; Figure S3 |
| `cell_daytime.csv.gz` | 412,903 | practice, month, and weekday time cell: inbound, menu ended, missed, and callback requested calls | tables; Figure 3 |
| `cell_daytime_xh.csv.gz` | 412,858 | the same without bank holidays and December 22 to January 2 | Table S3 |
| `daily_rush.csv.gz` | 1,678,918 | practice and day: calls between 8 AM and 10 AM by type of day | tables |
| `practice_summary.csv.gz` | 5051 | practice: totals over October 2025 to June 2026 | tables; Figure S2 |
| `practice_ref.csv.gz`, `pw_urban.csv.gz` | 6268 | practice: location, deprivation tenth, urban share of registered patients | tables |
| `national_month.csv.gz` | 21 | month: national coverage of the collection | Figure S1 |
| `ext_link_min100.csv.gz` | 6268 | practice: telephony for January to March 2025 and 2026 linked to the GP Patient Survey 2024 to 2026; telephony values are missing for a window with fewer than 100 inbound calls (the main analysis) | tables |
| `ext_link.csv.gz` | 6268 | the same link without the 100-call rule | tables |
| `durations_month.csv.gz` | 58,834 | practice and month: inbound, menu ended, answered, missed, and callback requested calls, and answered and missed calls by duration, from NHS England's durations files | Tables 2, S2, S3, and S4 |
| `answered_wait_month.csv.gz` | 28,346 | practice and month: answered calls by waiting time and time of day, from NHS England's Calls Answered Metric files | Table S4 |
| `gpad_month.csv.gz` | 36,976 | practice and month: appointments, from NHS England's appointments in general practice files | Tables S2 and S3 |

## How to run

**Tables** (SAS 9.4 for Windows, TS1M5 or later; Base SAS and SAS/STAT): run `paper0_tables.sas` as a whole, for example in batch with `sas -sysin "C:\path\to\paper0_tables.sas"` (give the full path; about 20 minutes). The program reads the data files from the folder `data` next to it and writes the tables to the folder `output` next to it. If it cannot find its own folder (for example when it is submitted from an editor), set `DATA` and `OUT` in PART 0 (the only lines to edit), or set the environment variable `PAPER0_DATA` to the data folder. The data files are copied to the WORK folder and read from there into temporary libraries, which are deleted at the end (on the authors' computer the ZIP access method that reads the compressed files could not open a path holding Korean characters); if the path of the WORK folder itself holds non-ASCII characters, start SAS with `-work` set to a folder with an ASCII-only path.

**Figures** (Python 3.13.17, matplotlib 3.11.2, numpy 2.5.5, pandas 3.1.1): `python paper0_figures.py` in the folder of this file. The figures are written to the folder `figures`. The six figures are drawn one after another in one run, as the submitted figures were; with these versions they are reproduced pixel for pixel. The figures uploaded to the journal were saved from the same drawings at a lower resolution (at most 1200 pixels).

The tables are printed with "to" between interval limits and a space as thousands separator; the paper prints the same values in the journal's style. Random steps (bootstrap, randomisation tests) use fixed seeds, so the intervals reproduce exactly. The table program writes the table values only: numbers in the text, table footnotes, and figure legends, and the two SDs in Table S3, come from the authors' other programs, available from the corresponding author. Some figure values are typed into `paper0_figures.py`: those of Figure 2B and 2C and the rate ratio labels of Figure S2A from the tables, the counts of Figure 1 and the cells of Figures 3A, S2B, and S2C from the authors' programs for the numbers in the text and legends, and Figure 2A from NHS England's published summary (see the header of the program).

The datasets were built from the published files listed below; the programs that build them are available from the corresponding author.

## Source data and attribution

All inputs are openly published. The files are cited in the reference list of the manuscript.

- NHS England: cloud-based telephony data in general practice, including the day and time band, durations, and Calls Answered Metric files (Copyright NHS England; reusable under the Open Government Licence v3.0, as stated in the publication files); patients registered at a GP practice; general practice workforce; appointments in general practice; submissions via online consultation systems; Organisation Data Service files.
- GP Patient Survey practice results 2024 to 2026: conducted by Ipsos for NHS England and published at https://www.gp-patient.co.uk.
- Office for National Statistics, National Statistics Postcode Lookup (latitude, longitude, local authority district, and the area classification of practice postcodes): Source: Office for National Statistics licensed under the Open Government Licence v.3.0. Contains OS data © Crown copyright and database right 2026. Contains Royal Mail data © Royal Mail copyright and database right 2026.
- Ministry of Housing, Communities and Local Government: English indices of deprivation 2025 (Open Government Licence v3.0).
