# -*- coding: utf-8 -*-
# paper0_figures.py - the figures of: Missed calls to general practices and patients' reported ease of phone contact in
# England: a national observational study. Haedong Kim, Sihyun Oh, Hajae Jeon, Jaeyong Shin. Licence: MIT (see LICENSE).
# What it writes: Figure1.png, Figure2.png and Figure3.png (main article) and FigureS1.png, FigureS2.png and FigureS3.png
# (supplementary figures), in the folder 'figures' next to this file, and nothing else.
# Usage: python paper0_figures.py. It reads the data files (gzip-compressed CSV) in the folder 'data' next to this file
# (environment variable PAPER0_DATA for another folder), with the variable types of data/data_dictionary.csv.
# Figures S1 and S2, the bars of figure 3B, the lines of figure S3A and the bars of figure S3C are drawn from the data files. The
# other values are typed in: the estimates in figures 2B and 2C are those of Table 2 and Tables S2 and S5, and the rate ratio labels
# of figure S3A those of Table S1 panel C (written by paper0_tables.sas); the counts in figure 1 and the cells of figures 3A, S3B
# and S3D come from the authors' programs for the numbers in the text and legends (available from the corresponding author);
# figure 2A is NHS England's published summary for May 2026 (see the paper's references), its 11.3% abandoned computed from the
# published counts. The six figures are drawn one after another in one run (see the end of this file).
# Software: Python 3.13.17, matplotlib 3.11.2, numpy 2.5.5, pandas 3.1.1; with these versions the figures are reproduced
# pixel for pixel.
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.lines as mlines
from matplotlib.lines import Line2D
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.environ.get('PAPER0_DATA', os.path.join(HERE, 'data'))
FIGS = os.path.join(HERE, 'figures'); os.makedirs(FIGS, exist_ok=True)


def read_data(name):
    # One analysis dataset from the folder 'data': character variables as text (empty = ''), numeric variables as
    # floating point numbers (empty = missing), as in the SAS dataset of the same name.
    d = pd.read_csv(os.path.join(DATA, 'data_dictionary.csv'), dtype=str)
    d = d[d.dataset == name]
    char, num = list(d.name[d.type == 'char']), list(d.name[d.type == 'num'])
    df = pd.read_csv(os.path.join(DATA, name + '.csv.gz'), dtype={c: str for c in char}, keep_default_na=False,
                     na_values={c: [''] for c in num})
    df[num] = df[num].astype('float64')
    return df


def figure_1():
    # Figure 1: data sources, exclusions and analysis samples (flow chart).
    # Reads no data: the counts are typed in below. Each was produced by the authors' programs for the numbers in the
    # tables, text and legends; see the header of this file.

    ink = '#1a1a1a'; FILL = '#dbe4f0'; EDGE = '#2f6db3'; FILLX = '#eef1f6'
    GFILL = '#e3efe6'; GEDGE = '#3c8a5a'; CFILL = '#eef0f2'; CEDGE = '#7a7f87'
    PAD = 0.5; GAP = 0.6; LH = 3.4
    plt.rcParams.update({'font.family': 'DejaVu Sans'})
    fig, ax = plt.subplots(figsize=(8.6, 7.2), dpi=400)
    ax.set_xlim(0, 100); ax.set_ylim(0, 100); ax.axis('off')


    def box(x, y, w, h, lines, fill=FILL, fs=8.4, edge=EDGE, centre=True):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=%s,rounding_size=1.2' % PAD,
                                    facecolor=fill, edgecolor=edge, linewidth=1.1, zorder=2))
        lh = LH * fs / 8.4                      # fixed line height from the top
        y0 = y + h - (h - len(lines) * lh) / 2 if centre else y + h - 1.2
        for i, ln in enumerate(lines):
            ax.text(x + w / 2, y0 - (i + 0.5) * lh, ln, ha='center', va='center', fontsize=fs, color=ink,
                    fontweight='bold' if i == 0 else 'normal', zorder=3)
        return dict(t=y + h + PAD + GAP, b=y - PAD - GAP, l=x - PAD - GAP, r=x + w + PAD + GAP, cx=x + w / 2, cy=y + h / 2)


    def line(pts, color=EDGE):
        xs, ys = zip(*pts)
        ax.plot(xs, ys, color=color, lw=1.2, solid_joinstyle='miter', solid_capstyle='butt', zorder=1)


    def arrow(p, q, color=EDGE):
        ax.add_patch(FancyArrowPatch(p, q, arrowstyle='-|>', mutation_scale=11, color=color, linewidth=1.2,
                                     shrinkA=0, shrinkB=0, zorder=1))


    def note(x, y, s, ha='left'):
        ax.text(x, y, s, ha=ha, va='center', fontsize=6.9, color=ink, style='italic', zorder=3)


    # tier 1: the three data sources
    FS1 = 7.0
    # tier 1 boxes hold eight lines: the 2024 wave is used for trends and for the falsification test
    gps = box(1, 74.5, 29, 23.5, ['GP Patient Survey', '(Ipsos for NHS England)', 'practice-level results,', '2024, 2025, and 2026:',
                              'share finding it easy to', 'contact the practice by phone;', '2024 only for trends and',
                              'the falsification test'],
              fill=GFILL, edge=GEDGE, fs=FS1)
    tel = box(33.5, 74.5, 33, 23.5, ['NHS England cloud-based telephony', 'October 2024 to June 2026 (21 months)',
                                 'Day and time band data:', '168 monthly source files;',
                                 'monthly practice data: used only to', 'check totals (June 2026: 4960 of 6145',
                                 'practices); time to answer data'], fs=FS1)
    chs = box(70, 74.5, 29, 23.5, ['Practice characteristics', 'registered patients (age, sex,', 'neighborhood of residence);',
                               'English indices of deprivation 2025;', 'postcode lookup; practice and',
                               'network records; workforce; online', 'consultations; appointments'],
              fill=CFILL, edge=CEDGE, fs=FS1)
    # side: exclusion; tier 2: practice attributable series
    exc = box(54, 58.5, 25, 12, ['Excluded', 'calls under shared accounts, not', 'attributable to a practice', '(7.0% of weekday calls)'],
              fill=FILLX, fs=6.9)
    mid = box(30, 45, 40, 10, ['Practice-attributable data', '5070 practices; 82,628 practice months;', '503 million weekday inbound calls'], fs=8.0)
    xs = tel['cx']
    arrow((xs, tel['b']), (xs, mid['t']))
    arrow((xs, exc['cy']), (exc['l'], exc['cy']))
    # practice characteristics -> practice attributable data (linked by practice code and month)
    xc = 92
    line([(xc, chs['b']), (xc, mid['cy'])], color=CEDGE)
    arrow((xc, mid['cy']), (mid['r'], mid['cy']), color=CEDGE)
    note(xc - 1, mid['cy'] + 3.6, 'linked by practice\ncode and month', ha='right')

    # tier 3: four analysis sets
    W, H, Y, FS3 = 23.0, 22, 3, 7.4
    xs4 = [1.0, 26.0, 51.0, 76.0]
    a1 = box(xs4[0], Y, W, H, ['GP Patient Survey linkage', 'Telephony, January to March', '(≥100 inbound calls)',
                               '2025: 3070 practices', '2026: 4913 practices', 'Change within', 'practices: 2995'], fs=FS3, centre=False)
    a2 = box(xs4[1], Y, W, H, ['Time-of-day comparisons', 'October 2025 to June 2026:', '5051 practices with data,',
                               '5049 with ≥1000', 'weekday calls;', '253.6 million calls'], fs=FS3, centre=False)
    a3 = box(xs4[2], Y, W, H, ['Telephony trends', 'Practices reporting in', 'all 21 months:', '2631 practices'], fs=FS3, centre=False)
    a4 = box(xs4[3], Y, W, H, ['Type-of-day analysis', 'Daily data, 21 months:', '428 days', '(bank holidays and', 'December 22 to',
                               'January 2 excluded)'], fs=FS3, centre=False)
    ybus = (mid['b'] + a1['t']) / 2
    xa1 = a1['cx'] + 4                      # bus enters the linkage box right of centre; the survey line enters on the left
    line([(mid['cx'], mid['b']), (mid['cx'], ybus)])
    line([(xa1, ybus), (a4['cx'], ybus)])
    arrow((xa1, ybus), (xa1, a1['t']))
    for a in (a2, a3, a4):
        arrow((a['cx'], ybus), (a['cx'], a['t']))
    # GP Patient Survey -> linkage box (separate source, linked by practice code)
    xg = 6
    line([(xg, gps['b']), (xg, ybus)], color=GEDGE)
    arrow((xg, ybus), (xg, a1['t']), color=GEDGE)
    note(xg + 1.2, (gps['b'] + mid['cy']) / 2, 'linked by\npractice code')

    plt.savefig(os.path.join(FIGS, 'Figure1.png'), bbox_inches='tight', facecolor='white')
    print('saved Figure1')


def figure_2():
    # Figure 2: classification of inbound calls and the association of each definition with reported ease.
    # Reads no data. Panel A: NHS England's published monthly summary for May 2026 (see the paper's references), typed in.
    # Panels B and C: estimates typed in from Table 2 and Tables S2 (panels A and B) and S5 (Table2.txt, TableS2.txt, TableS5.txt).
    # Panel B labels are kept within the left half of the figure and panel C within the right half.
    # Panel B rows follow the order of table 2; panel C marks each category with its own symbol so that the figure reads in
    # black and white.

    plt.rcParams.update({'font.family':'Arial','font.size':7,'axes.linewidth':.6,
        'xtick.major.width':.6,'xtick.major.size':2.5,'text.color':'#333333',
        'axes.labelcolor':'#333333','xtick.color':'#333333','ytick.color':'#333333'})
    ANS,CB,MENU,MISS='#C4CCD1','#7B5EA7','#3D8A5A','#D9641E'
    INK='#333333'; W25='#A9B6BD'; W26='#4A6572'

    fig=plt.figure(figsize=(6.2,4.55), dpi=610)
    A=fig.add_axes([0.050,0.790,0.905,0.120])
    B=fig.add_axes([0.055,0.092,0.385,0.428])
    C=fig.add_axes([0.530,0.092,0.430,0.452])

    SEG=[(54.8,ANS,'Answered by staff'),(7.3,CB,'Callback requested'),
         (26.6,MENU,'Ended in the automated menu'),(11.3,MISS,'Abandoned before being answered')]
    H=.34; left=0
    for val,col,lab in SEG:
        A.barh(0,val,left=left,height=H,color=col,edgecolor='white',linewidth=.8,zorder=2)
        A.text(left+val/2,0,f'{val}',ha='center',va='center_baseline',fontsize=6.5,
               color='white' if col!=ANS else INK,fontweight='bold',zorder=4)
        left+=val
    A.add_patch(plt.Rectangle((62.1,-H/2),26.6,H,facecolor='none',edgecolor=INK,
                              linewidth=1.3,zorder=5))

    def brk(x0,x1,y,d,text,ha_text='center'):
        A.plot([x0,x0,x1,x1],[y,y+d,y+d,y],color=INK,lw=.8,solid_joinstyle='miter',zorder=3)
        A.text((x0+x1)/2,y+d*1.35,text,ha=ha_text,va='bottom' if d>0 else 'top',
               fontsize=7.0,color=INK,fontweight='bold')
    brk(0,88.7, H/2+.04,  .13, 'NHS England counts these as "dealt with": 88.7%')
    brk(0,62.1,-H/2-.04, -.13, 'answered by staff or requested a callback: 62.1%')

    A.annotate('the 26.6% the two classifications disagree about',
               xy=(78.0,-H/2-.02), xytext=(100,-.70), fontsize=6.6, color=MENU,
               fontweight='bold', ha='right', va='center',
               arrowprops=dict(arrowstyle='-|>',color=MENU,lw=.9,
                               connectionstyle='arc3,rad=0.25',shrinkA=2,shrinkB=3))
    A.set_xlim(-1,101); A.set_ylim(-1.00,.75); A.set_yticks([])
    A.set_xticks([0,20,40,60,80,100]); A.set_xlabel('% of all inbound calls',
                                                    fontsize=6.9,labelpad=2)
    for s_ in ('top','right','left'): A.spines[s_].set_visible(False)
    A.xaxis.grid(True,color='#EEEEEE',linewidth=.6); A.set_axisbelow(True)
    hs=[plt.Rectangle((0,0),1,1,color=c) for c in (ANS,CB,MENU,MISS)]
    fig.legend(hs,[x[2] for x in SEG],loc='upper left',bbox_to_anchor=(0.050,0.700),
               ncol=4,frameon=False,fontsize=6.4,handlelength=1.0,handleheight=.8,
               columnspacing=1.1,handletextpad=.4)

    DEF=[('Abandonment (official measure)',10.6,(0.16,0.14,0.18),(0.12,0.10,0.14)),
         ('Real time nonconnection (+ callback)',17.7,(0.27,0.24,0.30),(0.18,0.16,0.20)),
         ('Queue restricted abandonment',14.5,(0.25,0.22,0.28),(0.17,0.15,0.19)),
         ('Queue restricted nonconnection',24.2,(0.33,0.30,0.36),(0.23,0.21,0.25)),
         ('Total nonconnection (+ menu ended)',44.5,(0.41,0.38,0.44),(0.31,0.28,0.33)),
         ('Comparison: answered calls waiting >2 minutes',None,(0.34,0.31,0.36),(0.30,0.28,0.32))]
    ys=np.arange(len(DEF))[::-1]*1.0
    ys[-1]-=0.25
    EK=dict(ecolor='#333333',elinewidth=.6,capsize=1.4,capthick=.6)
    for y,(lab,lvl,r25,r26) in zip(ys,DEF):
        B.barh(y+0.10,r25[0],height=.20,color=W25,xerr=[[r25[0]-r25[1]],[r25[2]-r25[0]]],error_kw=EK)
        B.barh(y-0.14,r26[0],height=.20,color=W26,xerr=[[r26[0]-r26[1]],[r26[2]-r26[0]]],error_kw=EK)
        _s = '  2025 wave' if y == ys[0] else ''
        _t = '  2026 wave' if y == ys[0] else ''
        B.text(r25[2]+.008,y+0.10,f'{r25[0]:.2f}{_s}',va='center',fontsize=6.0,color='#6B7A82')
        B.text(r26[2]+.008,y-0.14,f'{r26[0]:.2f}{_t}',va='center',fontsize=6.0,color=W26,fontweight='bold')
        if lvl is None:
            txt=lab
        else:
            txt=f'{lab}   \u00b7   {lvl}%'+('*' if lab.startswith('Queue') else '')
        B.text(0.004,y+0.30,txt,fontsize=6.3,va='bottom',color=INK,fontweight='bold')
    B.axhline((ys[-2]+ys[-1])/2+0.05,color='#BBBBBB',lw=.6,ls=(0,(3,2)))
    B.set_yticks([])
    B.set_xlim(0,0.50); B.set_ylim(ys[-1]-0.48,len(DEF)-0.80)
    B.set_xticks([0,0.1,0.2,0.3,0.4,0.5])
    B.set_xlabel('variation between practices in reported ease that the definition\nexplains (weighted R²)',fontsize=6.5,labelpad=2,linespacing=1.3)
    for s in ('top','right','left'): B.spines[s].set_visible(False)
    B.tick_params(axis='y',length=0)
    B.xaxis.grid(True,color='#EEEEEE',linewidth=.6); B.set_axisbelow(True)

    BLOCKS=[('Reported ease, across practices 2026',
             [(-0.89,-0.97,-0.81,MISS),(-0.47,-0.54,-0.41,CB),(-0.72,-0.78,-0.67,MENU)]),
            ('Reported ease, practices sharing a postcode 2026',
             [(-0.76,-1.12,-0.39,MISS),(-0.39,-0.71,-0.06,CB),(-0.42,-0.74,-0.09,MENU)]),
            ('Learned the next step there and then, 2026',
             [(-0.256,-0.326,-0.186,MISS),(0.096,0.037,0.155,CB),(-0.416,-0.466,-0.366,MENU)])]
    C.axvline(0,color='#AAAAAA',lw=.7,zorder=1)
    MK={MISS:'o',CB:'s',MENU:'^'}
    ytop=0.0; GAP=1.15; BLOCKH=3*0.62
    tops=[]
    for bi,(name,rows) in enumerate(BLOCKS):
        top = -bi*(BLOCKH+GAP)
        tops.append(top)
        for ri,(est,lo,hi,col) in enumerate(rows):
            y = top - 0.30 - ri*0.62
            C.plot([lo,hi],[y,y],color=col,lw=1.5,solid_capstyle='round',zorder=2)
            C.plot([est],[y],MK[col],color=col,ms=4.2,zorder=3,markeredgecolor='white',markeredgewidth=.6)
        C.text(-1.195, top+0.06, name, fontsize=6.5, fontweight='bold', color=INK, va='bottom', zorder=3, bbox=dict(facecolor='white', edgecolor='none', pad=0.6))
        if bi: C.axhline(top+GAP*0.60, color='#E2E6E8', lw=.7, zorder=0)
    C.set_yticks([]); C.set_ylim(tops[-1]-BLOCKH-0.10, 0.62); C.set_xlim(-1.20,0.40)
    C.set_xticks([-1.0,-0.5,0,0.5]); C.set_xticklabels(['\u22121.0','\u22120.5','0','0.5'])
    C.set_xlabel('difference in the share of patients giving that answer,\nin percentage points, per percentage point of calls',fontsize=6.5,labelpad=2,linespacing=1.3)
    for s_ in ('top','right','left'): C.spines[s_].set_visible(False)
    C.tick_params(axis='y',length=0)
    C.xaxis.grid(True,color='#EEEEEE',linewidth=.6); C.set_axisbelow(True)
    C.legend([mlines.Line2D([],[],color=c,marker=MK[c],ms=4.2,lw=1.5,
                            markeredgecolor='white',markeredgewidth=.6)
              for c in (MISS,CB,MENU)],
             ['Abandoned','Callback diverted','Menu ended'],
             loc='upper right', bbox_to_anchor=(1.03,0.945), frameon=False, fontsize=6.4,
             handlelength=1.3, labelspacing=.30, handletextpad=.5)

    fig.text(0.010,0.962,'A',fontsize=8.6,fontweight='bold')
    fig.text(0.040,0.964,'Composition of inbound calls, May 2026',fontsize=7.3,fontweight='bold')
    fig.text(0.010,0.618,'B',fontsize=8.6,fontweight='bold')
    fig.text(0.040,0.620,'Calls counted vs variation in ease explained',
             fontsize=7.3,fontweight='bold')
    fig.text(0.040,0.604,'each measure entered alone; R² uses January to March;\n'
             'bars 95% CI; % of calls over 21 months (*of calls passing the menu)',
             fontsize=6.3,color='#6B7A82',linespacing=1.25,va='top')
    fig.text(0.470,0.618,'C',fontsize=8.6,fontweight='bold')
    fig.text(0.500,0.620,'Difference in patient-reported outcomes',fontsize=7.3,fontweight='bold')
    fig.text(0.500,0.596,'all 3 categories in one model, vs calls answered by staff; 95% CI',
             fontsize=6.3,color='#6B7A82')
    fig.canvas.draw(); _r = fig.canvas.get_renderer(); _W = fig.bbox.width
    _bx = [t for t in fig.texts + B.texts if t.get_text().strip()]
    _right_B = max(t.get_window_extent(_r).x1 for t in _bx if t.get_window_extent(_r).x0 < 0.46 * _W)
    _left_C = min(t.get_window_extent(_r).x0 for t in fig.texts + C.texts if t.get_window_extent(_r).x0 >= 0.46 * _W)
    assert _right_B <= 0.465 * _W and _left_C >= 0.465 * _W, (_right_B / _W, _left_C / _W)
    fig.savefig(os.path.join(FIGS,'Figure2.png'),dpi=610,facecolor='white')
    print('saved')


def figure_3():
    # Figure 3: (A) reported ease by fifth of abandonment and fifth of menu ended share; (B) call outcomes by
    # weekday time cell. Panel B reads data/cell_daytime.csv.gz. Panel A cell means are typed in; the figure prints them
    # to whole numbers, as in the figure legend and main text.
    OUT=FIGS
    ink='#333333'; muted='#777777'; ORANGE='#d9641e'; PURPLE='#7b5ea7'; GREEN='#3d8a5a'
    # Font sizes are set so that the figure, reduced to the text width of an A4 page, prints at about 7 pt or more; the
    # callback segment is hatched so that panel B reads in black and white.
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':12,'axes.titlesize':13,'axes.labelsize':12.5,'xtick.labelsize':11.5,'ytick.labelsize':11.5,'legend.fontsize':11,'hatch.linewidth':1.0})
    FS_ANN=11
    def despine(ax, grid='y'):
        for s in ['top','right']: ax.spines[s].set_visible(False)
        if grid: ax.grid(axis=grid, color='#eeeeee', lw=0.7)
        ax.set_axisbelow(True); ax.tick_params(labelsize=11.5, color=muted)
    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=8)
    cd=read_data('cell_daytime')
    st=cd[cd.month.astype(int)>=202510].groupby('cell')[['CBT001','CBT002','CBT004','CBT005']].sum()
    st['A']=st.CBT004/st.CBT001*100; st['cb']=st.CBT005/st.CBT001*100; st['menu']=st.CBT002/st.CBT001*100
    order=['rush_TueFri','rush_Mon','midday','late']; lab=['Rush,\nTue to Fri\n8 AM-\n10 AM','Rush,\nMonday\n8 AM-\n10 AM','Midday,\nMon to Fri\n10 AM-\n4 PM','Late afternoon,\nMon to Fri\n4 PM-\n6:30 PM']
    st=st.loc[order]
    grid=np.array([[79.7,76.6,73.8,67.8,59.6],[76.7,71.4,65.9,64.6,53.4],[71.6,68.2,62.2,55.1,51.7],[68.2,63.2,58.5207,54.4,48.7],[63.6,54.2,51.8,48.1,45.6]])
    fig=plt.figure(figsize=(9.8,5.4), dpi=400)
    gs=fig.add_gridspec(1,2, width_ratios=[1.0,1.5], wspace=0.32)
    # Panel A: heatmap (unchanged except axis titles and panel letter)
    ax=fig.add_subplot(gs[0])
    cmap=plt.get_cmap('cividis')
    ax.imshow(grid, cmap=cmap, aspect='auto', vmin=44, vmax=82)
    for i in range(5):
        for j in range(5): ax.text(j,i,f'{grid[i,j]:.0f}',ha='center',va='center',fontsize=12,color=ink if grid[i,j]>=66 else 'white',fontweight='bold')
    ax.set_xticks(range(5)); ax.set_xticklabels(['lowest','2','3','4','highest'],fontsize=11.5,color=ink)
    ax.set_yticks(range(5)); ax.set_yticklabels(['lowest','2','3','4','highest'],fontsize=11.5,color=ink)
    ax.set_xlabel('Abandonment (official measure), fifth'); ax.set_ylabel('Calls ending in the automated menu, fifth')
    for s in ax.spines.values(): s.set_visible(False)
    ax.tick_params(length=0)
    title(ax,'A  % finding phone contact easy')
    # Panel B: stacked bars (unchanged except panel letter)
    ax=fig.add_subplot(gs[1]); x=np.arange(4)
    ax.bar(x, st.A, 0.58, color=ORANGE, label='Abandoned (the official measure)')
    ax.bar(x, st.cb, 0.58, bottom=st.A, color=PURPLE, hatch='///', edgecolor='white', linewidth=0, label='Callback requested\n(real time nonconnection adds these)')
    ax.bar(x, st.menu, 0.58, bottom=st.A+st.cb, color=GREEN, label='Ended in the automated menu\n(total nonconnection adds these too)')
    for i in x:
        ax.text(i, st.A.iloc[i]/2, f'{st.A.iloc[i]:.1f}', ha='center', va='center', fontsize=FS_ANN, color='white', fontweight='bold')
        ax.text(i, st.A.iloc[i]+st.cb.iloc[i]/2, f'{st.cb.iloc[i]:.1f}', ha='center', va='center', fontsize=FS_ANN, color='white', fontweight='bold',
                bbox=dict(facecolor=PURPLE, edgecolor='none', pad=0.8))
        ax.text(i, st.A.iloc[i]+st.cb.iloc[i]+st.menu.iloc[i]/2, f'{st.menu.iloc[i]:.1f}', ha='center', va='center', fontsize=FS_ANN, color='white', fontweight='bold')
        tot=st.A.iloc[i]+st.cb.iloc[i]+st.menu.iloc[i]; ax.text(i, tot+1.2, f'Total {tot:.1f}', ha='center', fontsize=FS_ANN, color=ink, fontweight='bold')
    ax.set_xticks(x); ax.set_xticklabels(lab, fontsize=11, color=ink); ax.set_ylim(0,100); ax.set_yticks([0,20,40,60,80])
    ax.set_ylabel('% of inbound calls'); _h, _l = ax.get_legend_handles_labels()
    ax.legend(_h[::-1], _l[::-1], frameon=False, loc='upper left', fontsize=11); despine(ax)  # stacking order, top first
    title(ax,'B  Call outcomes by weekday time cell')
    plt.savefig(f'{OUT}/Figure3.png', dpi=600, bbox_inches='tight', facecolor='white'); plt.close(); print('saved Figure3')


def figure_S1():
    # Figure S1: (A, B) coverage of the cloud-based telephony collection by month (reads data/national_month.csv.gz); (C) the
    # abandonment rate of each practice with at least 1000 weekday calls, October 2025 to June 2026, by NHS England region (reads
    # data/practice_summary.csv.gz and data/ext_link.csv.gz), with each region's call-weighted rate over the same practices and
    # window (total abandoned / total inbound weekday calls). Drawn at the text width of a page (7.2 inches).
    OUT = FIGS
    ink = '#333333'; muted = '#777777'; BLUE = '#2f6db3'; PURPLE = '#7b5ea7'; RED = '#c8402a'; LGRAY = '#c9ced4'
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 7.5, 'axes.titlesize': 8,
                         'axes.labelsize': 7.5, 'xtick.labelsize': 7, 'ytick.labelsize': 7})

    def despine(ax):
        for s in ['top', 'right']: ax.spines[s].set_visible(False)
        ax.grid(axis='y', color='#eeeeee', lw=0.7); ax.set_axisbelow(True)
        ax.tick_params(labelsize=7, color=muted)

    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=6)

    df = read_data('national_month')
    x = range(len(df))
    lab = [m[:4] + '-' + m[4:] for m in df['month']]
    ticks = [i for i, m in enumerate(df['month']) if m[4:] in ('10', '02', '06')]

    fig = plt.figure(figsize=(7.2, 6.4))
    gs = fig.add_gridspec(2, 2, height_ratios=[1.0, 1.35], hspace=0.62, wspace=0.28)
    ax = fig.add_subplot(gs[0, 0])
    ax.plot(x, df['n'], color=BLUE, lw=1.5, marker='o', ms=3)
    title(ax, 'A  Practices reporting each month'); ax.set_ylabel('Practices'); ax.set_xlabel('Month')
    ax.set_ylim(2000, 5300); despine(ax)
    ax.set_xticks(ticks); ax.set_xticklabels([lab[i] for i in ticks])

    ax = fig.add_subplot(gs[0, 1])
    ax.plot(x, df['share'] * 100, color=PURPLE, lw=1.5, marker='o', ms=3)
    title(ax, 'B  Share of registered population covered')
    ax.set_ylabel('% of registered patients'); ax.set_xlabel('Month'); ax.set_ylim(40, 90); despine(ax)
    ax.set_xticks(ticks); ax.set_xticklabels([lab[i] for i in ticks])

    # panel C: practices by region (the former Figure S7 of the earlier draft)
    NAME = {'Y56': 'London', 'Y58': 'South West', 'Y59': 'South East', 'Y60': 'Midlands', 'Y61': 'East of England',
            'Y62': 'North West', 'Y63': 'North East and Yorkshire'}
    sm = read_data('practice_summary')
    e = read_data('ext_link')[['practice_code', 'region_code']]
    sm = sm[(sm.inbound_stablewin >= 1000) & sm.lat.notna()].copy()
    sm['ab'] = 100 * sm.abandoned_stablewin / sm.inbound_stablewin
    sm = sm.merge(e, left_on='practice', right_on='practice_code', how='left')
    sm['region'] = sm.region_code.map(NAME)
    assert len(sm) == 5049 and sm.region.notna().all(), (len(sm), sm.region.isna().sum())
    rg = sm.groupby('region')[['abandoned_stablewin', 'inbound_stablewin']].sum()
    reg = 100 * rg.abandoned_stablewin / rg.inbound_stablewin      # same practices and window as the dots
    lo, hi = np.percentile(sm.ab, [20, 80])
    order = reg.sort_values().index.tolist()          # London (lowest regional rate) at the top
    CAP = 50
    rng = np.random.default_rng(20261016)
    ax = fig.add_subplot(gs[1, :])
    ylab = []
    for i, r in enumerate(order[::-1]):
        v = sm.loc[sm.region == r, 'ab'].values
        yy = i + rng.uniform(-0.28, 0.28, len(v))
        col = np.where(v <= lo, BLUE, np.where(v >= hi, RED, LGRAY))
        ax.scatter(np.minimum(v, CAP), yy, s=2.5, c=col, alpha=0.75, linewidths=0, zorder=2)
        q1, med, q3 = np.percentile(v, [25, 50, 75])
        ax.plot([q1, q3], [i, i], color=ink, lw=1.8, zorder=3, solid_capstyle='butt')
        ax.plot([med, med], [i - 0.33, i + 0.33], color=ink, lw=1.3, zorder=3)
        ax.plot(reg[r], i, marker='D', ms=3.8, mfc='white', mec=ink, mew=0.9, zorder=4)
        nb, nw, over = int((v <= lo).sum()), int((v >= hi).sum()), int((v > CAP).sum())
        extra = f'; {over} above {CAP}%' if over else ''
        ylab.append(f'{r}\nn={len(v)}; best fifth {nb}, worst fifth {nw}{extra}')
    ax.set_yticks(range(len(order))); ax.set_yticklabels(ylab, fontsize=6.3, linespacing=1.15)
    ax.axvline(lo, color=BLUE, lw=0.7, ls=':'); ax.axvline(hi, color=RED, lw=0.7, ls=':')
    ax.set_xlim(0, CAP); ax.set_ylim(-0.6, len(order) - 0.4)
    ax.set_xlabel('Abandoned calls, % of inbound calls (practice rate, October 2025 to June 2026)')
    for sp in ('top', 'right', 'left'): ax.spines[sp].set_visible(False)
    ax.tick_params(axis='y', length=0); ax.grid(axis='x', color='#eeeeee', lw=0.7); ax.set_axisbelow(True)
    h = [Line2D([], [], marker='o', ls='', color=BLUE, ms=3.5, label=f'Best fifth (≤{lo:.1f}%)'),
         Line2D([], [], marker='o', ls='', color=RED, ms=3.5, label=f'Worst fifth (≥{hi:.1f}%)'),
         Line2D([], [], marker='o', ls='', color=LGRAY, ms=3.5, label='Middle three fifths'),
         Line2D([], [], color=ink, lw=1.8, label='Interquartile range; tick = median'),
         Line2D([], [], marker='D', ls='', mfc='white', mec=ink, ms=3.8, label='Regional call-weighted rate')]
    ax.legend(handles=h, loc='upper center', bbox_to_anchor=(0.45, -0.17), ncol=3, frameon=False, fontsize=6.3)
    title(ax, 'C  Abandonment by NHS England region')
    plt.savefig(f'{OUT}/FigureS1.png', dpi=600, bbox_inches='tight', facecolor='white'); plt.close()
    print('saved FigureS1', '| fifths', round(lo, 1), round(hi, 1), '| regions', {k: round(v, 1) for k, v in reg.items()},
          '| above 50%', int((sm.ab > CAP).sum()))


def figure_S2():
    # Figure S2: call volume, abandonment and real time nonconnection by weekday and 2-hour time band, October 2025 to June 2026,
    # all practices with day and time data (reads data/weekday_band.csv.gz, the national sums of the day and time band files).
    # Drawn at the text width of a page.
    OUT = FIGS
    ink = '#333333'; muted = '#777777'
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 7, 'axes.titlesize': 8, 'axes.labelsize': 7,
                         'xtick.labelsize': 7, 'ytick.labelsize': 7})
    wb = read_data('weekday_band')
    w = wb[(wb.month >= '202510') & (wb.weekday.isin(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']))].copy()
    BAND = {'06:00-07:59': '6 AM to\n8 AM*', '08:00-09:59': '8 AM to\n10 AM', '10:00-11:59': '10 AM to\n12 PM',
            '12:00-13:59': '12 PM to\n2 PM', '14:00-15:59': '2 PM to\n4 PM', '16:00-17:59': '4 PM to\n6 PM'}
    w = w[w.band.isin(BAND)].copy(); w['b'] = w.band.map(BAND)
    gg = w.groupby(['weekday', 'b'])[['CBT001', 'CBT004', 'CBT005']].sum().reset_index()
    days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']; bands = list(BAND.values())
    piv = lambda col: gg.pivot(index='weekday', columns='b', values=col).loc[days, bands]
    vol = piv('CBT001'); volp = 100 * vol / vol.values.sum()
    Ar = 100 * piv('CBT004') / vol; Br = 100 * (piv('CBT004') + piv('CBT005')) / vol
    fig, axes = plt.subplots(3, 1, figsize=(6.5, 6.6), layout='constrained')
    fig.get_layout_engine().set(h_pad=0.06, hspace=0.06)
    for ax_, M, cmap, t in [(axes[0], volp, 'Blues', 'A  Call volume (% of weekday calls, 6 AM to 6 PM)'),
                            (axes[1], Ar, 'Oranges', 'B  Abandoned call rate (%)'),
                            (axes[2], Br, 'Purples', 'C  Real time nonconnection rate (%)')]:
        day = M.values[:, 1:]
        Mm = np.ma.masked_array(M.values, mask=np.zeros_like(M.values, dtype=bool)); Mm.mask[:, 0] = True
        cm = plt.get_cmap(cmap).copy(); cm.set_bad('#e9eaec')
        ax_.imshow(Mm, cmap=cm, aspect='auto', vmin=np.nanmin(day), vmax=np.nanmax(day))
        for i in range(M.shape[0]):
            for j in range(M.shape[1]):
                v = M.values[i, j]
                c = muted if j == 0 else ('white' if v > np.nanpercentile(day, 70) else ink)
                ax_.text(j, i, '%.1f' % v, ha='center', va='center', fontsize=7, color=c)
        ax_.set_xticks(range(len(bands))); ax_.set_xticklabels(bands); ax_.set_yticks(range(len(days)))
        ax_.set_yticklabels(['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'])
        ax_.set_title(t, loc='left', color=ink, fontweight='bold', pad=5)
        for sp in ax_.spines.values(): sp.set_visible(False)
        ax_.tick_params(length=0)
    plt.savefig(f'{OUT}/FigureS2.png', dpi=600, facecolor='white'); plt.close()
    tf = ['Tue', 'Wed', 'Thu', 'Fri']
    def cell(df, d, cols):
        return df.loc[d, cols].values.sum()
    rush, mid, late = [BAND['08:00-09:59']], [BAND['10:00-11:59'], BAND['12:00-13:59'], BAND['14:00-15:59']], [BAND['16:00-17:59']]
    out = {}
    for nm, cols in (('rush', rush), ('midday', mid), ('late', late)):
        vm, vt = cell(vol, ['Mon'], cols), cell(vol, tf, cols)
        am, at_ = cell(piv('CBT004'), ['Mon'], cols), cell(piv('CBT004'), tf, cols)
        cbm, cbt = cell(piv('CBT005'), ['Mon'], cols), cell(piv('CBT005'), tf, cols)
        out[nm] = dict(rtnc_mon=round(100 * (am + cbm) / vm, 1), rtnc_tf=round(100 * (at_ + cbt) / vt, 1),
                       cb_gap=round(100 * cbm / vm - 100 * cbt / vt, 1), gap=round(100 * (am + cbm) / vm - 100 * (at_ + cbt) / vt, 1))
    print('saved FigureS2 | Monday 10 AM to 12 PM abandoned', round(Ar.loc['Mon', BAND['10:00-11:59']], 1), '|', out,
          '| rush volume share', round(volp[[BAND['08:00-09:59']]].values.sum(), 1))


def figure_S3():
    # Figure S3: deprivation and change over time, 4 panels, drawn at the text width of a page (7.2 inches).
    # Panel A reads data/practice_summary.csv.gz; its rate ratio labels are typed in from Table S1 panel C. Panel C reads
    # data/practice_month.csv.gz. Panels B and D are typed in from the authors' programs for the numbers in the text.
    OUT = FIGS
    ink='#333333'; muted='#777777'
    BLUE='#2f6db3'; ORANGE='#d9641e'; GRAY='#9aa0a6'; PURPLE='#7b5ea7'
    RED='#c8402a'; LGRAY='#c9ced4'; GREEN='#3d8a5a'; LBLUE='#9fbbe0'
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':7.5,'axes.titlesize':8,'axes.labelsize':7.5,
                         'xtick.labelsize':7,'ytick.labelsize':7,'legend.fontsize':6.3})
    FS_ANN=6.3
    DEC=['1\nmost\ndeprived','2','3','4','5','6','7','8','9','10\nleast\ndeprived']
    def despine(ax, grid='y'):
        for s in ['top','right']: ax.spines[s].set_visible(False)
        if grid: ax.grid(axis=grid, color='#eeeeee', lw=0.7)
        ax.set_axisbelow(True); ax.tick_params(labelsize=7, color=muted)
    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=6)

    ps = read_data('practice_summary')
    ps['A']=ps.abandoned_stablewin/ps.inbound_stablewin*100
    ps['B']=(ps.abandoned_stablewin+ps.callback_req_stablewin)/ps.inbound_stablewin*100
    ps['W']=(ps.abandoned_stablewin+ps.callback_req_stablewin+ps.menu_stablewin)/ps.inbound_stablewin*100
    ge=ps.groupby('pw_imd_decile_1poorest')[['A','B','W']].mean()
    ease=pd.Series([57.2,60.4,61.1,61.0,61.3,63.0,62.6,64.1,63.8,63.5], index=range(1,11))
    COH=[('In the collection from October to December 2024 (n=2918)',(55.9,59.3,62.6),BLUE,'o','-'),
         ('Entered January to September 2025 (n=1265)',(54.7,57.6,61.6),'#4a7fc0','s','--'),
         ('Entered October 2025 or later (n=866)',(53.7,56.4,60.1),LBLUE,'^','-.'),
         ('Never in the collection (n=1092)',(52.3,55.2,58.3),GRAY,'D',':')]
    pm=read_data('practice_month')
    o=pm[(pm.cbt_observed==1)&pm.pw_imd_decile_1poorest.notna()]
    g=o.groupby('practice_code').agg(decile=('pw_imd_decile_1poorest','max'),
                                     ever=('cbt005_cb_requested',lambda x:(x.fillna(0)>0).any()))
    t=g.groupby('decile').ever.agg(['sum','count']); t['pct']=100*t['sum']/t['count']
    assert (t.loc[1.0,'sum'],t.loc[1.0,'count'])==(386,451), t.loc[1.0]
    assert (t.loc[10.0,'sum'],t.loc[10.0,'count'])==(516,544), t.loc[10.0]
    dec=t.index.astype(int).values; pct=t.pct.values

    fig=plt.figure(figsize=(7.2,6.5)); gs=fig.add_gridspec(2,2, hspace=0.52, wspace=0.30)
    xd=np.arange(1,11)
    # Panel A: failure under 3 definitions by deprivation decile
    ax=fig.add_subplot(gs[0,0])
    for col,c,name,rr in [('W',GREEN,'Total nonconnection','RR 1.06 (1.01 to 1.11)'),
                          ('B',PURPLE,'Real time nonconnection','RR 1.14 (1.04 to 1.24)'),
                          ('A',ORANGE,'Abandonment (official)','RR 1.24 (1.13 to 1.36)')]:
        ax.plot(xd, ge[col], color=c, lw=1.5, marker='o', ms=3, label=f'{name}; {rr}')
    ax.set_xticks(xd); ax.set_xticklabels(DEC); ax.set_xlim(0.6,10.4); ax.set_ylim(0,52)
    ax.set_ylabel('% of calls (mean of practice rates)'); ax.set_xlabel('Patient-weighted deprivation decile')
    ax.legend(frameon=False, loc='center', bbox_to_anchor=(0.5,0.60)); despine(ax)
    title(ax,'A  Failed calls under 3 definitions')
    # Panel B: reported ease by the same deciles
    ax=fig.add_subplot(gs[0,1]); cols=[RED if d_==1 else LGRAY for d_ in xd]
    ax.bar(xd, ease.values, 0.62, color=cols)
    for d_,v_ in zip(xd, ease.values): ax.text(d_, v_+1.2, f'{v_:.1f}', ha='center', fontsize=FS_ANN, color=ink)
    ax.set_ylim(0,75); ax.set_yticks([0,20,40,60]); ax.set_xticks(xd); ax.set_xticklabels(DEC)
    ax.set_xlabel('Patient-weighted deprivation decile')
    ax.set_ylabel('% of patients finding phone\ncontact easy, 2026'); despine(ax)
    title(ax,'B  Reported ease of phone contact')
    # Panel C: practices that ever recorded callback use
    ax=fig.add_subplot(gs[1,0])
    ax.bar(dec,pct,0.62,color=[PURPLE if d_==1 else LGRAY for d_ in dec])
    for x_,v_ in zip(dec,pct): ax.text(x_, v_+1.5, '%.1f'%v_, ha='center', fontsize=FS_ANN, color=ink)
    ax.set_ylim(0,110); ax.set_yticks([0,20,40,60,80,100]); ax.set_xticks(xd); ax.set_xticklabels(DEC)
    ax.set_ylabel('% of practices ever recording\ncallback use'); despine(ax)
    ax.set_xlabel('Patient-weighted deprivation decile')
    title(ax,'C  Practices ever recording callback use')
    # Panel D: reported ease by survey year and entry cohort
    ax=fig.add_subplot(gs[1,1])
    for name,vals,c,mk,ls_ in COH:
        ax.plot([2024,2025,2026], vals, color=c, lw=1.5, ls=ls_, marker=mk, ms=3.5, label=name)
        ax.text(2026.06, vals[-1], f'+{vals[-1]-vals[0]:.1f}', fontsize=FS_ANN, color=ink, va='center', fontweight='bold')  # dark text: the light line colours are too pale for 6 pt labels
    ax.set_xticks([2024,2025,2026]); ax.set_xlim(2023.8,2026.4); ax.set_ylim(50,72); ax.set_yticks([50,55,60,65,70])
    ax.set_ylabel('% of patients finding phone\ncontact easy'); ax.set_xlabel('GP Patient Survey year')
    ax.legend(frameon=False, loc='upper left', fontsize=6.3, borderaxespad=0.2, handlelength=2.2, handletextpad=0.5); despine(ax)
    title(ax,'D  Reported ease by entry cohort')

    plt.savefig(f'{OUT}/FigureS3.png', dpi=600, bbox_inches='tight', facecolor='white'); plt.close()
    print('saved FigureS3')


FIGURES = [figure_1, figure_2, figure_3, figure_S1, figure_S2, figure_S3]

if __name__ == '__main__':
    # One run, in this order, from Matplotlib's default settings. Settings that a figure changes stay in effect for the
    # figures after it, as when the figures of the paper were drawn, so a figure drawn on its own can differ slightly in line
    # widths and text colours.
    matplotlib.rc_file_defaults()
    for draw in FIGURES:
        plt.close('all')
        draw(); print(draw.__name__, 'done')
