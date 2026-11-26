# Missed Calls to General Practices and Patients' Reported Ease of Phone Contact in England

Code and data that reproduce the tables and figures of the paper (release v16.08).
Authors: Haedong Kim, Sihyun Oh, Hajae Jeon, Jaeyong Shin. Code licence: MIT (see `LICENSE`).

## Contents

- `paper0_tables.sas`: writes Tables 1-4 and S1-S5 to `output/` (SAS 9.4 TS1M5 or later, Base SAS and SAS/STAT).
- `paper0_figures.py`: draws Figures 1-3 and S1-S3 in `figures/` (Python 3.13, matplotlib 3.11.2, numpy 2.5.5, pandas 3.1.1).
- `data/`: practice-level datasets (`.csv.gz`), described in `data/data_dictionary.csv`.

## How to run

- Tables: `sas -sysin "C:\path\to\paper0_tables.sas"` (about 20 minutes; if needed, set `DATA` and `OUT` in PART 0).
- Figures: `python paper0_figures.py`

## Data sources

Openly published data: NHS England (Open Government Licence v3.0); GP Patient Survey (Ipsos for NHS England); English indices of deprivation 2025, Ministry of Housing, Communities and Local Government (Open Government Licence v3.0); National Statistics Postcode Lookup. Source: Office for National Statistics licensed under the Open Government Licence v.3.0. Contains OS data © Crown copyright and database right 2026. Contains Royal Mail data © Royal Mail copyright and database right 2026.
