# -*- coding: utf-8 -*-
# paper0_figures.py - every figure of: Do missed calls to general practices reflect patients' reported ease of phone
# contact? (figures 1 to 3 and supplementary figures S1 to S9). Haedong Kim, Sihyun Oh, Hajae Jeon, Jaeyong Shin.
# Licence: MIT (see LICENSE).
# Usage: python paper0_figures.py, with the environment variable PAPER0_ROOT (or PAPER0_SAS_OUT) set to the folder
# holding SAS_OUT. The figures are written to the folder 'figures' next to this file (Figure1.png ... FigureS9.png).
# Figures S2 to S5, S7, S9, panel B of S6 and the bars of 3B and S8A are drawn from the datasets in SAS_OUT. The other
# values are typed in: the estimates in 2B, 2C, S6A and S8A are those in the table outputs of paper0_tables.sas; the
# counts in figures 1 and S1 and the cells of 3A, S8B and S8C come from the authors' programs for the numbers in the
# text and legends; figure 2A is NHS England's published summary for May 2026 (see the paper's references), its 11.3% abandoned
# computed from the published counts. Each figure starts from Matplotlib's default settings, as in a new process.
# Software: Python 3.13.15, matplotlib 3.11.2, numpy 2.5.4, pandas 3.1.0 (pandas.read_sas reads the SAS datasets);
# with these versions the figures are reproduced byte for byte (figures other than 1 and S8 were first drawn with
# matplotlib 3.11.1, numpy 2.5.1 and pandas 3.0.5, with the same pixels). Figure S9 was revised on 10 November 2026 (values
# inside the bars) and drawn with matplotlib 3.11.1, numpy 2.5.1 and pandas 3.0.5.
import os
import sys, os
import os, datetime as dt
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np
import matplotlib.lines as mlines
import numpy as np, pandas as pd, matplotlib
from matplotlib.colors import LinearSegmentedColormap
import matplotlib.dates as mdates
import pandas as pd, matplotlib
import matplotlib.patheffects as pe
from matplotlib.lines import Line2D

HERE = os.path.dirname(os.path.abspath(__file__))
SAS_OUT = os.environ.get('PAPER0_SAS_OUT', os.path.join(os.environ.get('PAPER0_ROOT', HERE), 'SAS_OUT'))
FIGS = os.path.join(HERE, 'figures'); os.makedirs(FIGS, exist_ok=True)


def figure_1():
    # Figure 1: data sources, exclusions and analysis samples (flow chart).
    # Reads no data: the counts are typed in below. Each was produced by the authors' programs for the numbers in the
    # tables, text and legends; see README.md, Figures.

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
    gps = box(1, 74.5, 29, 23.5, ['GP Patient Survey', '(Ipsos for NHS England)', 'practice level results,', '2024, 2025, and 2026:',
                              'share finding it easy to', 'contact the practice by phone;', '2024 only for trends and',
                              'the falsification test'],
              fill=GFILL, edge=GEDGE, fs=FS1)
    tel = box(33.5, 74.5, 33, 23.5, ['NHS England cloud based telephony', 'October 2024 to June 2026 (21 months)',
                                 'Day and time band data:', '168 monthly source files;',
                                 'monthly practice data: used only to', 'check totals (June 2026: 4960 of 6145',
                                 'practices); time to answer data'], fs=FS1)
    chs = box(70, 74.5, 29, 23.5, ['Practice characteristics', 'registered patients (age, sex,', 'neighbourhood of residence);',
                               'English indices of deprivation 2025;', 'postcode lookup; practice and',
                               'network records; workforce; online', 'consultations; appointments'],
              fill=CFILL, edge=CEDGE, fs=FS1)
    # side: exclusion; tier 2: practice attributable series
    exc = box(54, 58.5, 25, 12, ['Excluded', 'calls under shared accounts, not', 'attributable to a practice', '(7.0% of weekday calls)'],
              fill=FILLX, fs=6.9)
    mid = box(30, 45, 40, 10, ['Practice attributable data', '5070 practices; 82 628 practice months;', '503 million weekday inbound calls'], fs=8.0)
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
    a2 = box(xs4[1], Y, W, H, ['Time of day comparisons', 'October 2025 to June 2026:', '5051 practices with data,',
                               '5049 with ≥1000', 'weekday calls;', '253.6 million calls'], fs=FS3, centre=False)
    a3 = box(xs4[2], Y, W, H, ['Trends', 'Practices reporting in', 'all 21 months:', '2631 practices'], fs=FS3, centre=False)
    a4 = box(xs4[3], Y, W, H, ['Type of day analysis', 'Daily data, 21 months:', '428 days', '(bank holidays and', '22 December to',
                               '2 January excluded)'], fs=FS3, centre=False)
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
    plt.savefig(os.path.join(FIGS, 'Figure1.svg'), bbox_inches='tight', facecolor='white')
    print('saved Figure1')


def figure_2():
    # Figure 2: classification of inbound calls and the association of each definition with reported ease.
    # Reads no data. Panel A: NHS England's published monthly summary for May 2026 (see the paper's references), typed in.
    # Panels B and C: estimates typed in from output/T2_table2.txt, TS2_tableS2.txt, TS4_tableS4.txt and TS7_tableS7.txt.
    # Panel B labels are kept within the left half of the figure and panel C within the right half (co-author comment).
    # Panel B rows follow the order of table 2; panel C marks each category with its own symbol so that the figure reads in
    # black and white (mock review R7).

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

    DEF=[('Abandonment (published measure)',10.6,(0.16,0.14,0.18),(0.12,0.10,0.14)),
         ('Real time non-connection (+ callback)',17.7,(0.27,0.24,0.30),(0.18,0.16,0.20)),
         ('Queue restricted abandonment',14.5,(0.25,0.22,0.28),(0.17,0.15,0.19)),
         ('Queue restricted non-connection',24.2,(0.33,0.30,0.36),(0.23,0.21,0.25)),
         ('Total non-connection (+ menu ended)',44.5,(0.41,0.38,0.44),(0.31,0.28,0.33)),
         ('Comparison: answered calls waiting >2 min',None,(0.34,0.31,0.36),(0.30,0.28,0.32))]
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
            ('Learned the next step there and then',
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
    C.set_xlabel('change in the share of patients giving that answer,\nin percentage points, per percentage point of calls',fontsize=6.5,labelpad=2,linespacing=1.3)
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
    fig.text(0.040,0.620,'Calls counted v variation in ease explained',
             fontsize=7.3,fontweight='bold')
    fig.text(0.040,0.604,'each measure entered alone; R² uses January to March;\n'
             'bars 95% CI; % of calls over 21 months (*of calls passing the menu)',
             fontsize=6.3,color='#6B7A82',linespacing=1.25,va='top')
    fig.text(0.470,0.618,'C',fontsize=8.6,fontweight='bold')
    fig.text(0.500,0.620,'Change in patient reported outcomes',fontsize=7.3,fontweight='bold')
    fig.text(0.500,0.596,'all three components in one model, v calls answered by staff; 95% CI',
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
    # weekday time cell. Panel B reads SAS_OUT/cell_daytime. Panel A cell means are typed in; the figure prints them
    # to whole numbers, as in the figure legend and main text (see README.md, Figures).
    B=SAS_OUT+'/'; OUT=FIGS
    ink='#333333'; muted='#777777'; ORANGE='#d9641e'; PURPLE='#7b5ea7'; GREEN='#3d8a5a'
    # Font sizes are set so that the figure, reduced to the text width of an A4 page, prints at about 7 pt or more (mock
    # review R7); the callback segment is hatched so that panel B reads in black and white.
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':12,'axes.titlesize':13,'axes.labelsize':12.5,'xtick.labelsize':11.5,'ytick.labelsize':11.5,'legend.fontsize':11,'hatch.linewidth':1.0})
    FS_ANN=11
    def despine(ax, grid='y'):
        for s in ['top','right']: ax.spines[s].set_visible(False)
        if grid: ax.grid(axis=grid, color='#eeeeee', lw=0.7)
        ax.set_axisbelow(True); ax.tick_params(labelsize=11.5, color=muted)
    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=8)
    cd=pd.read_sas(B+'cell_daytime.sas7bdat', encoding='latin1')
    st=cd[cd.month.astype(int)>=202510].groupby('cell')[['CBT001','CBT002','CBT004','CBT005']].sum()
    st['A']=st.CBT004/st.CBT001*100; st['cb']=st.CBT005/st.CBT001*100; st['menu']=st.CBT002/st.CBT001*100
    order=['rush_TueFri','rush_Mon','midday','late']; lab=['Rush,\nTue to Fri\n08:00 to\n10:00','Rush,\nMonday\n08:00 to\n10:00','Midday,\nMon to Fri\n10:00 to\n16:00','Late afternoon,\nMon to Fri\n16:00 to\n18:30']
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
    ax.bar(x, st.cb, 0.58, bottom=st.A, color=PURPLE, hatch='///', edgecolor='white', linewidth=0, label='Diverted to a callback\n(real time non-connection adds these)')
    ax.bar(x, st.menu, 0.58, bottom=st.A+st.cb, color=GREEN, label='Ended in the automated menu\n(total non-connection adds these too)')
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
    # Figure S1: study framework (data flow and timeline).
    # Reads no data: the counts are typed in below; each is printed by an exhibit program (see README.md, Figures).

    plt.rcParams.update({'font.family': 'DejaVu Sans'})
    INK = '#1a1a1a'; MUTED = '#5f6b73'
    EDGE = '#2f6db3'; FILL = '#dbe4f0'      # telephony
    EDGE2 = '#3d8a5a'; FILL2 = '#e3f0e7'    # survey
    EDGE3 = '#7a7f85'; FILL3 = '#eef0f2'    # characteristics, secondary
    FILLP = '#fbe9dc'; EDGEP = '#b8571a'    # primary analyses
    PAD = 0.35                               # FancyBboxPatch pad: the drawn edge lies PAD outside the nominal box
    GAP = 0.45                               # clear space between a box edge and an arrow end

    fig = plt.figure(figsize=(11.6, 9.0), dpi=400)
    A = fig.add_axes([0.01, 0.37, 0.98, 0.56]); A.set_xlim(0, 100); A.set_ylim(0, 104); A.axis('off')
    B = fig.add_axes([0.20, 0.06, 0.77, 0.24])


    def box(x, y, w, h, lines, fill, edge, fs=8.0, bold=1, lw=1.1):
        A.add_patch(FancyBboxPatch((x, y), w, h, boxstyle='round,pad=%s,rounding_size=1.0' % PAD,
                                   facecolor=fill, edgecolor=edge, linewidth=lw, zorder=2))
        n = len(lines)
        for i, ln in enumerate(lines):
            yy = y + h - (i + 0.5) * (h / n)
            A.text(x + w / 2, yy, ln, ha='center', va='center', fontsize=fs, color=INK,
                   fontweight='bold' if i < bold else 'normal', zorder=3)
        return dict(l=x - PAD - GAP, r=x + w + PAD + GAP)


    def arrow(pts, col):
        """Polyline through pts (orthogonal segments), arrow head on the last segment."""
        if len(pts) > 2:
            xs, ys = zip(*pts[:-1])
            A.plot(xs, ys, color=col, lw=1.1, solid_joinstyle='miter', solid_capstyle='butt', zorder=1)
        A.add_patch(FancyArrowPatch(pts[-2], pts[-1], arrowstyle='-|>', mutation_scale=10, color=col,
                                    linewidth=1.1, shrinkA=0, shrinkB=0, zorder=1))


    for x, t in [(17, 'Data sources'), (50.5, 'Measures'), (83.5, 'Analyses')]:
        A.text(x, 99.0, t, ha='center', va='bottom', fontsize=9.2, fontweight='bold', color=MUTED)

    # data sources
    A.add_patch(FancyBboxPatch((1, 55), 32, 41, boxstyle='round,pad=%s,rounding_size=1.0' % PAD,
                               facecolor='white', edgecolor=EDGE, linewidth=1.3, zorder=2))
    A.text(17, 93.2, 'NHS England cloud based telephony', ha='center', va='center', fontsize=8.4, fontweight='bold', color=INK, zorder=3)
    A.text(17, 89.6, 'October 2024 to June 2026 (21 months)', ha='center', va='center', fontsize=7.8, color=INK, zorder=3)
    box(3, 76.0, 28, 10.6, ['Day and time band data', 'outcome of each inbound call by', 'weekday and 2 hour band;', 'summed to practice months'], FILL, EDGE, fs=7.4)
    box(3, 66.6, 28, 7.2, ['Monthly practice data', 'used only to check the totals'], FILL3, EDGE3, fs=7.4)
    box(3, 57.0, 28, 7.6, ['Time to answer data', 'answered calls by waiting band'], FILL, EDGE, fs=7.6)
    TEL_R = 1 + 32 + PAD + GAP
    SUR = box(1, 30, 32, 17, ['GP Patient Survey (separate source)', 'practice level, 2024 to 2026 waves',
                              'outcome: share finding it easy', 'to contact the practice by phone'], FILL2, EDGE2, fs=7.7)
    CHA = box(1, 4, 32, 17, ['Practice characteristics', 'list size, age composition,', 'deprivation, workforce,',
                             'region, postcode'], FILL3, EDGE3, fs=7.7)

    # measures
    DEF = box(37, 59, 27, 37, ['Five definitions of a failed call', 'Abandonment (official measure)',
                               'Queue restricted abandonment', 'Real time non-connection', '(+ callback requests)',
                               'Queue restricted non-connection', 'Total non-connection', '(+ menu ended calls)'],
              FILL, EDGE, fs=7.5)
    WAI = box(37, 41, 27, 12, ['Waiting time (comparison)', 'share of answered calls', 'waiting more than 2 min'], FILL, EDGE, fs=7.6)
    LNK = box(37, 17, 27, 18, ['Linkage by practice code', 'telephony January to March', 'of each survey year:',
                               '4913 practices (2026), 3070 (2025)'], FILL2, EDGE2, fs=7.6)

    # analyses: timing next to the definitions; definitions v reports next to waiting time and linkage
    TIM = box(68, 70, 31, 26, ['Primary analysis:', 'timing of failed calls', 'rate ratios between weekday time',
                               'periods within practice and month;', 'October 2025 to June 2026,', '5049 practices'],
              FILLP, EDGEP, fs=7.6, bold=2, lw=1.4)
    REP = box(68, 39, 31, 25, ['Primary analysis:', "definitions v patients' reports", 'variance in reported ease between',
                               'practices explained by each', 'definition (weighted R²);', 'waiting time for comparison'],
              FILLP, EDGEP, fs=7.6, bold=2, lw=1.4)
    SEC = box(68, 4, 31, 29, ['Secondary analyses', 'how menu ended calls change the', 'official measure; abandoned, callback',
                              'diverted, and menu ended components;', 'shared postcodes; within practice', 'change; variance; deprivation'],
              FILL3, EDGE3, fs=7.4)

    # sources -> measures (straight where boxes face each other, one elbow for time to answer -> waiting time)
    arrow([(TEL_R, 81), (DEF['l'], 81)], EDGE)
    xl = (TEL_R + WAI['l']) / 2
    arrow([(TEL_R, 61), (xl, 61), (xl, 47), (WAI['l'], 47)], EDGE)
    arrow([(SUR['r'], 32), (LNK['l'], 32)], EDGE2)
    # measures -> analyses
    arrow([(DEF['r'], 83), (TIM['l'], 83)], EDGEP)        # definitions -> timing
    arrow([(DEF['r'], 61.5), (REP['l'], 61.5)], EDGEP)    # definitions -> definitions v reports
    arrow([(WAI['r'], 47), (REP['l'], 47)], EDGEP)        # waiting time -> definitions v reports
    xg = (LNK['r'] + REP['l']) / 2
    arrow([(LNK['r'], 33), (xg, 33), (xg, 42), (REP['l'], 42)], EDGE2)   # linkage -> definitions v reports
    arrow([(LNK['r'], 22), (SEC['l'], 22)], EDGE3)        # linkage -> secondary
    arrow([(CHA['r'], 10), (SEC['l'], 10)], EDGE3)        # characteristics -> secondary
    fig.text(0.010, 0.968, 'A', fontsize=12, fontweight='bold')
    fig.text(0.035, 0.969, 'Data flow: sources, measures, and analyses', fontsize=10, fontweight='bold')

    # timeline
    D = dt.date
    LIGHT = '#9fb8dc'
    # each segment: start, end, colour, label, label position ('left' above the bar start, 'right' above the bar end,
    # 'before' to the left of the bar), bar height, vertical offset within the row
    rows = [
        ('Telephony data\n(available)', [(D(2024, 10, 1), D(2026, 6, 30), EDGE, 'available for all 21 months: monthly and day and time data', 'left', 0.52, 0)]),
        ('Comparison window\n(main)', [(D(2025, 10, 1), D(2026, 6, 30), '#6f95c9', 'main: 9 months after the contract change', 'left', 0.52, 0)]),
        ('Comparison window\n(repeated)', [(D(2024, 10, 1), D(2026, 6, 30), LIGHT, 'all 21 months', 'before', 0.22, 0.15),
                                           (D(2024, 10, 1), D(2025, 9, 30), LIGHT, 'Oct 2024 to Sep 2025', 'before', 0.22, -0.15)]),
        ('GP Patient Survey\nfieldwork', [(D(2024, 1, 1), D(2024, 4, 15), EDGE2, '2024 wave', 'left', 0.52, 0),
                                         (D(2025, 1, 1), D(2025, 4, 15), EDGE2, '2025 wave', 'left', 0.52, 0),
                                         (D(2026, 1, 1), D(2026, 4, 15), EDGE2, '2026 wave', 'left', 0.52, 0)]),
        ('Telephony linked\nto each survey', [(D(2025, 1, 1), D(2025, 3, 31), '#8fbf9f', 'January to March only (whole months within fieldwork)', 'left', 0.52, 0),
                                              (D(2026, 1, 1), D(2026, 3, 31), '#8fbf9f', 'January to March', 'left', 0.52, 0)]),
    ]
    for i, (lab, segs) in enumerate(rows):
        y = len(rows) - 1 - i
        for s_, e, c, t, al, hh, dy in segs:
            B.barh(y + dy, mdates.date2num(e) - mdates.date2num(s_), left=mdates.date2num(s_), height=hh, color=c, edgecolor='none')
            if al == 'before':
                B.text(mdates.date2num(s_) - 6, y + dy, t, fontsize=7.0, color=INK, va='center', ha='right', zorder=3)
                continue
            xt = mdates.date2num(s_) + 6 if al == 'left' else mdates.date2num(e)
            B.text(xt, y + 0.40, t, fontsize=7.0, color=INK, va='bottom', ha=al, zorder=3)
    B.text(mdates.date2num(D(2026, 6, 30)), len(rows) - 3 + 0.33, 'time of day and deprivation comparisons only', fontsize=6.6,
           color=MUTED, ha='right', va='bottom', style='italic')
    B.set_yticks(range(len(rows))); B.set_yticklabels([r[0] for r in rows][::-1], fontsize=8, color=INK)
    ev = mdates.date2num(D(2025, 10, 1))
    B.axvline(ev, color=EDGEP, lw=1.2, ls='--', zorder=0)
    B.text(ev - 4, len(rows) - 0.35, 'October 2025: GP contract change\n(online consultation open in core hours)',
           fontsize=7.0, color=EDGEP, ha='right', va='bottom')
    B.set_xlim(mdates.date2num(D(2023, 12, 1)), mdates.date2num(D(2026, 8, 1)))
    B.set_ylim(-0.6, len(rows) + 0.55)
    B.xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1, 4, 7, 10]))
    B.xaxis.set_major_formatter(mdates.DateFormatter('%b\n%Y'))
    B.tick_params(axis='x', labelsize=7.5, colors=INK); B.tick_params(axis='y', length=0)
    for s in ('top', 'right', 'left'): B.spines[s].set_visible(False)
    B.xaxis.grid(True, color='#eeeeee', lw=0.6); B.set_axisbelow(True)
    fig.text(0.010, 0.325, 'B', fontsize=12, fontweight='bold')
    fig.text(0.035, 0.326, 'Timeline: data periods, survey waves, and the October 2025 contract change', fontsize=10, fontweight='bold')

    for ext in ('png', 'svg'):
        fig.savefig(os.path.join(FIGS, 'FigureS1.' + ext), facecolor='white', bbox_inches='tight')
    print('saved FigureS1')


def figure_S2():
    # Figure S2: coverage of the cloud based telephony collection by month (reads SAS_OUT/national_month).
    OUT = FIGS
    ink = '#333333'; muted = '#777777'; BLUE = '#2f6db3'; PURPLE = '#7b5ea7'
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 8, 'axes.titlesize': 9,
                         'axes.labelsize': 8.5, 'xtick.labelsize': 8, 'ytick.labelsize': 8})

    def despine(ax):
        for s in ['top', 'right']: ax.spines[s].set_visible(False)
        ax.grid(axis='y', color='#eeeeee', lw=0.7); ax.set_axisbelow(True)
        ax.tick_params(labelsize=8, color=muted)

    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=8)

    df = pd.read_sas(os.path.join(SAS_OUT,'national_month.sas7bdat'))
    df['month'] = df['month'].str.decode('latin1')
    x = range(len(df))
    lab = [m[:4] + '-' + m[4:] for m in df['month']]
    ticks = [i for i, m in enumerate(df['month']) if m[4:] in ('10', '02', '06')]

    fig, axes = plt.subplots(1, 2, figsize=(11.3, 3.35))
    ax = axes[0]
    ax.plot(x, df['n'], color=BLUE, lw=2, marker='o', ms=4)
    title(ax, 'A  Practices reporting each month'); ax.set_ylabel('Practices')
    ax.set_ylim(2000, 5300); despine(ax)
    ax.set_xticks(ticks); ax.set_xticklabels([lab[i] for i in ticks])

    ax = axes[1]
    ax.plot(x, df['share'] * 100, color=PURPLE, lw=2, marker='o', ms=4)
    title(ax, 'B  Share of the registered population of England covered')
    ax.set_ylabel('% of registered patients'); ax.set_ylim(40, 90); despine(ax)
    ax.set_xticks(ticks); ax.set_xticklabels([lab[i] for i in ticks])

    plt.tight_layout()
    plt.savefig(f'{OUT}/FigureS2.png', dpi=400, bbox_inches='tight', facecolor='white')
    print('saved FigureS2')


def figure_S3():
    # Figure S3: concentration of calls in 08:00 to 10:00 (reads SAS_OUT/cell_daytime, practice_month,
    # practice_summary).

    B = SAS_OUT+'/'
    OUT = FIGS
    ink='#333333'; muted='#777777'
    BLUE='#2f6db3'; ORANGE='#d9641e'; GRAY='#9aa0a6'
    FS_TICK = 7; FS_LAB = 7.5; FS_TITLE = 8.5; FS_ANN = 7.5
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':FS_TICK,'axes.titlesize':FS_TITLE,'axes.labelsize':FS_LAB,
                         'xtick.labelsize':FS_TICK,'ytick.labelsize':FS_TICK,'legend.fontsize':FS_TICK})
    def despine(ax, grid='y'):
        for s in ['top','right']: ax.spines[s].set_visible(False)
        if grid: ax.grid(axis=grid, color='#eeeeee', lw=0.7)
        ax.set_axisbelow(True); ax.tick_params(labelsize=FS_TICK, color=muted)
    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=6)
    MONTH = {'01':'Jan','02':'Feb','03':'Mar','04':'Apr','05':'May','06':'Jun','07':'Jul','08':'Aug','09':'Sep','10':'Oct','11':'Nov','12':'Dec'}

    def _load(name):
        fp = B + name + ".sas7bdat"
        if not os.path.exists(fp):
            print(f"  [skipped] {name}.sas7bdat not found"); return None
        return pd.read_sas(fp, encoding='latin1')
    cd = _load("cell_daytime")
    pm = _load("practice_month")
    ps = _load("practice_summary")
    obs = pm[pm.cbt_observed == 1]
    bal = set(obs.groupby('practice_code').month.nunique().pipe(lambda s: s[s == 21]).index)
    V = {}

    cb = cd[cd.practice.isin(bal)].copy(); cb['rush'] = cb.cell.str.startswith('rush')
    g = cb.groupby(['month', 'rush'])[['CBT001', 'CBT004']].sum().unstack()
    share = 100*g[('CBT001', True)]/(g[('CBT001', True)]+g[('CBT001', False)])
    arush = 100*g[('CBT004', True)]/g[('CBT001', True)]
    arest = 100*g[('CBT004', False)]/g[('CBT001', False)]
    ri = (100*ps.rush_inbound/ps.inbound_stablewin).dropna()
    mon = [MONTH[m[4:]]+' '+m[:4] for m in share.index]
    tk = [i for i, m in enumerate(share.index) if m[4:] in ('10', '02', '06')]
    fig, ax = plt.subplots(3, 1, figsize=(6.2, 7.6), layout='constrained')
    fig.get_layout_engine().set(h_pad=0.08, hspace=0.06)
    ax[0].hist(ri, bins=np.arange(5, 80, 1.5), color=BLUE, edgecolor='white', lw=0.4)
    ax[0].axvline(ri.median(), color=ink, ls='--', lw=1.1)
    ax[0].text(ri.median()+1.5, ax[0].get_ylim()[1]*0.93, 'median %.1f%%' % ri.median(), fontsize=FS_ANN, color=ink)
    title(ax[0], 'A  Share of weekday calls received 08:00 to 10:00,\n     by practice (October 2025 to June 2026)')
    ax[0].set_xlabel('% of weekday calls in 08:00 to 10:00'); ax[0].set_ylabel('Practices'); despine(ax[0])
    ax[1].plot(range(len(share)), share.values, color=BLUE, lw=1.6, marker='o', ms=3.2)
    title(ax[1], 'B  Share of weekday calls in 08:00 to 10:00, by month\n     (balanced panel, %d practices)' % len(bal))
    ax[1].set_ylabel('% of weekday calls'); ax[1].set_ylim(20, 34); despine(ax[1])
    ax[1].set_xticks(tk); ax[1].set_xticklabels([mon[i] for i in tk])
    ax[2].plot(range(len(arush)), arush.values, color=ORANGE, lw=1.6, label='08:00 to 10:00 calls')
    ax[2].plot(range(len(arest)), arest.values, color=GRAY, lw=1.6, label='Rest of the weekday')
    title(ax[2], 'C  Abandoned call rate, 08:00 to 10:00 v rest of the weekday\n     (balanced panel)')
    ax[2].set_ylabel('% of calls abandoned'); despine(ax[2]); ax[2].legend(frameon=False, loc='lower left')
    ax[2].set_xticks(tk); ax[2].set_xticklabels([mon[i] for i in tk])
    plt.savefig(f'{OUT}/FigureS3.png', dpi=600, facecolor='white'); plt.close()
    V['S3'] = dict(median_rush=round(ri.median(), 1), share=[round(v, 2) for v in share.values],
                   arush=[round(v, 2) for v in arush.values], arest=[round(v, 2) for v in arest.values], n_bal=len(bal), ticks=[mon[i] for i in tk])
    print('saved FigureS3')


def figure_S4():
    # Figure S4: call volume, abandonment and real time non-connection by weekday and time band, October 2025 to
    # June 2026 (reads SAS_OUT/weekday_band).

    B = SAS_OUT+'/'
    OUT = FIGS
    ink='#333333'; muted='#777777'
    FS_CELL = 8; FS_TICK = 7.5; FS_TITLE = 8.5
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':FS_TICK,'axes.titlesize':FS_TITLE,'axes.labelsize':FS_TICK,
                         'xtick.labelsize':FS_TICK,'ytick.labelsize':FS_TICK,'legend.fontsize':FS_TICK})

    def _load(name):
        fp = B + name + ".sas7bdat"
        if not os.path.exists(fp):
            print(f"  [skipped] {name}.sas7bdat not found"); return None
        return pd.read_sas(fp, encoding='latin1')
    wb = _load("weekday_band")
    V = {}
    if any(v is None for v in [wb]):
        print('  [skipped] Figure S4')
        sys.exit(1)
    else:
        w = wb[(wb.month >= '202510') & (wb.weekday.isin(['Mon', 'Tue', 'Wed', 'Thu', 'Fri']))].copy()
        BAND = {'06:00-07:59': '06:00 to\n08:00*', '08:00-09:59': '08:00 to\n10:00', '10:00-11:59': '10:00 to\n12:00',
                '12:00-13:59': '12:00 to\n14:00', '14:00-15:59': '14:00 to\n16:00', '16:00-17:59': '16:00 to\n18:00'}
        w = w[w.band.isin(BAND)].copy(); w['b'] = w.band.map(BAND)
        gg = w.groupby(['weekday', 'b'])[['CBT001', 'CBT004', 'CBT005']].sum().reset_index()
        days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']; bands = list(BAND.values())
        piv = lambda col: gg.pivot(index='weekday', columns='b', values=col).loc[days, bands]
        vol = piv('CBT001'); volp = 100*vol/vol.values.sum()
        Ar = 100*piv('CBT004')/vol; Br = 100*(piv('CBT004')+piv('CBT005'))/vol
        fig, axes = plt.subplots(3, 1, figsize=(6.2, 7.4), layout='constrained')
        fig.get_layout_engine().set(h_pad=0.08, hspace=0.07)
        for ax_, M, cmap, t in [(axes[0], volp, 'Blues', 'A  Call volume (% of weekday calls)'),
                                (axes[1], Ar, 'Oranges', 'B  Abandoned call rate (%)'),
                                (axes[2], Br, 'Purples', 'C  Real time non-connection rate (%)')]:
            day = M.values[:, 1:]
            Mm = np.ma.masked_array(M.values, mask=np.zeros_like(M.values, dtype=bool)); Mm.mask[:, 0] = True
            cm = plt.get_cmap(cmap).copy(); cm.set_bad('#e9eaec')
            im = ax_.imshow(Mm, cmap=cm, aspect='auto', vmin=np.nanmin(day), vmax=np.nanmax(day))
            for i in range(M.shape[0]):
                for j in range(M.shape[1]):
                    v = M.values[i, j]
                    if j == 0:
                        c = muted
                    else:
                        c = 'white' if v > np.nanpercentile(day, 70) else ink
                    ax_.text(j, i, '%.1f' % v, ha='center', va='center', fontsize=FS_CELL, color=c)
            ax_.set_xticks(range(len(bands))); ax_.set_xticklabels(bands); ax_.set_yticks(range(len(days))); ax_.set_yticklabels(days)
            ax_.set_title(t, loc='left', color=ink, fontweight='bold', pad=6)
            for s in ax_.spines.values(): s.set_visible(False)
            ax_.tick_params(length=0)
        plt.savefig(f'{OUT}/FigureS4.png', dpi=600, facecolor='white'); plt.close()
        V['S3'] = dict(mon_1012_A=round(Ar.loc['Mon', BAND['10:00-11:59']], 1), rush_vol_share=round(volp[[BAND['08:00-09:59']]].values.sum(), 1),
                       mon_rush_B=round(Br.loc['Mon', BAND['08:00-09:59']], 1))
        V['matrices'] = {k: np.round(M.values, 1).tolist() for k, M in [('vol', volp), ('A', Ar), ('B', Br)]}

    print('saved FigureS4')


def figure_S5():
    # Figure S5: failure rate by practice rush intensity (ventiles), October 2025 to June 2026
    # (reads SAS_OUT/practice_summary).

    B = SAS_OUT+'/'
    OUT = FIGS
    ink='#333333'; muted='#777777'
    BLUE='#2f6db3'; ORANGE='#d9641e'; GRAY='#9aa0a6'; PURPLE='#7b5ea7'; LGRAY='#c9ced4'; RED='#c8402a'
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':8,'axes.titlesize':9,'axes.labelsize':8.5,
                         'xtick.labelsize':8,'ytick.labelsize':8,'legend.fontsize':8})
    def despine(ax, grid='y'):
        for s in ['top','right']: ax.spines[s].set_visible(False)
        if grid: ax.grid(axis=grid, color='#eeeeee', lw=0.7)
        ax.set_axisbelow(True); ax.tick_params(labelsize=8, color=muted)
    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=8)

    def _load(name):
        import os
        fp = B + name + ".sas7bdat"
        if not os.path.exists(fp):
            print(f"  [skipped] {name}.sas7bdat not found"); return None
        return pd.read_sas(fp, encoding='latin1')
    cd = _load("cell_daytime")
    ps = _load('practice_summary')

    if any(v is None for v in [ps]):
        print('  [skipped] Figure S5')
        sys.exit(1)
    else:
        p = ps[(ps.inbound_stablewin > 0) & (ps.mon_rush_inbound > 0)].copy()
        p['ri'] = 100*p.rush_inbound/p.inbound_stablewin
        p['vent'] = pd.qcut(p.ri, 20, labels=False) + 1
        def band(dfg, num, den):
            x = 100*dfg[num]/dfg[den]
            x = x[np.isfinite(x)]
            r = x.mean(); se = x.std(ddof=1)/np.sqrt(len(x))
            return pd.Series({'rate': r, 'lo': r-1.96*se, 'hi': r+1.96*se, 'ri': dfg.ri.mean()})
        A = p.groupby('vent').apply(lambda d: band(d, 'abandoned_stablewin', 'inbound_stablewin'))
        p['nb'] = p.abandoned_stablewin + p.callback_req_stablewin
        Bv = p.groupby('vent').apply(lambda d: band(d, 'nb', 'inbound_stablewin'))
        p['mnb'] = p.mon_rush_abandoned + p.mon_rush_callback
        M = p.groupby('vent').apply(lambda d: band(d, 'mnb', 'mon_rush_inbound'))
        fig, ax = plt.subplots(1, 2, figsize=(11.3, 3.5))
        for series, col, lab in [(A, ORANGE, 'Abandonment'), (Bv, PURPLE, 'Real time non-connection')]:
            ax[0].plot(series.ri, series.rate, color=col, lw=2, marker='o', ms=3.5, label=lab)
            ax[0].fill_between(series.ri, series.lo, series.hi, color=col, alpha=0.15, lw=0)
        title(ax[0], 'A  Failure rate by practice rush intensity (ventiles)')
        ax[0].set_xlabel('% of weekday calls received 08:00 to 10:00'); ax[0].set_ylabel('% of inbound calls')
        despine(ax[0]); ax[0].legend(frameon=False)
        ax[1].plot(M.ri, M.rate, color=PURPLE, lw=2, marker='o', ms=3.5)
        ax[1].fill_between(M.ri, M.lo, M.hi, color=PURPLE, alpha=0.15, lw=0)
        title(ax[1], 'B  Monday 08:00 to 10:00 real time non-connection')
        ax[1].set_xlabel('% of weekday calls received 08:00 to 10:00'); ax[1].set_ylabel('% of inbound calls'); despine(ax[1])
        plt.tight_layout(); plt.savefig(f'{OUT}/FigureS5.png', dpi=400, bbox_inches='tight', facecolor='white'); plt.close()
    print('saved FigureS5')


def figure_S6():
    # Figure S6: (A) variance of abandonment by level; (B) practices sharing a postcode. Panel A shares are typed in
    # from output/TS3_tableS3.txt (variance components); panel B reads SAS_OUT/external_link_SAS.csv.
    OUT=FIGS
    ink='#333333'; muted='#777777'
    BLUE='#2f6db3'; RED='#c8402a'; LGRAY='#c9ced4'; GREEN='#3d8a5a'
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':8,'axes.titlesize':9,'axes.labelsize':8.5,
                         'xtick.labelsize':8,'ytick.labelsize':8,'legend.fontsize':8})
    FS_ANN=7.5
    def despine(ax, grid='y'):
        for s in ['top','right']: ax.spines[s].set_visible(False)
        if grid: ax.grid(axis=grid, color='#eeeeee', lw=0.7)
        ax.set_axisbelow(True); ax.tick_params(labelsize=8, color=muted)
    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=8)

    VC=[('Practices (5070)',                    68.0, True),
        ('Within a practice\n(month to month)',  20.2, False),
        ('Primary care networks\n(1240 + 26 single practices)',         6.9, False),
        ('Local authority\ndistricts (294)',       4.9, False)]

    l=pd.read_csv(os.path.join(SAS_OUT,'external_link_SAS.csv')).rename(columns={'ease_2026':'phone_easy_2026'})
    dd=l[l.A_w26.notna()&l.phone_easy_2026.notna()&l.postcode.notna()].copy()
    dd['pc']=dd.postcode.str.replace(' ','').str.upper()
    n=dd.groupby('pc').size(); s=dd[dd.pc.isin(n[n>=2].index)].copy()
    for v in ['A_w26','W_w26']: s[v+'_dm']=s[v]-s.groupby('pc')[v].transform('mean')
    s['y_dm']=s.phone_easy_2026-s.groupby('pc').phone_easy_2026.transform('mean')
    rW=np.corrcoef(s.y_dm,s.W_w26_dm)[0,1]; rA=np.corrcoef(s.y_dm,s.A_w26_dm)[0,1]
    slope=np.polyfit(s.W_w26_dm, s.y_dm, 1)
    assert len(s)==625 and s.pc.nunique()==278, (len(s), s.pc.nunique())

    fig=plt.figure(figsize=(12.8,4.4), dpi=400); gs=fig.add_gridspec(1,2, width_ratios=[1.25,1], wspace=0.28)
    ax=fig.add_subplot(gs[0]); y=np.arange(len(VC))[::-1]
    for i,(name,pct,hi) in enumerate(VC):
        ax.barh(y[i], pct, 0.62, color=BLUE if hi else LGRAY)
        ax.text(pct+1.0, y[i], f'{pct:.1f}%', va='center', fontsize=FS_ANN,
                color=ink, fontweight='bold' if hi else 'normal')
    ax.set_yticks(y); ax.set_yticklabels([n_ for n_,_,_ in VC], fontsize=8, color=ink)
    ax.set_xlabel('% of the variance in practice month abandonment'); ax.set_xlim(0,75)
    despine(ax, grid='x'); ax.tick_params(axis='y',length=0)
    title(ax,'A  Variance in practice month abandonment, by level')

    ax=fig.add_subplot(gs[1])
    ax.scatter(s.W_w26_dm, s.y_dm, s=11, color=GREEN, alpha=0.55, lw=0)
    xx=np.linspace(s.W_w26_dm.min(),s.W_w26_dm.max(),10); ax.plot(xx, slope[0]*xx+slope[1], color=ink, lw=1.2)
    ax.axhline(0,color=LGRAY,lw=0.8); ax.axvline(0,color=LGRAY,lw=0.8)
    ax.text(0.03,0.05,(f'{len(s)} practices at {s.pc.nunique()} sites sharing a postcode\nr={rW:.2f} (abandonment alone r={rA:.2f})').replace('-','\u2212'),
            transform=ax.transAxes,fontsize=FS_ANN,color=ink)
    ax.set_xlabel('Calls not reaching a person, percentage points from site mean, January to March 2026')
    ax.set_ylabel('Patients finding phone contact easy,\npercentage points from site mean, 2026'); ax.set_xlim(-38,38); ax.set_ylim(-42,42)
    despine(ax, grid=None)
    title(ax,'B  Practices sharing a postcode: call failure and reported ease')
    plt.savefig(f'{OUT}/FigureS6.png', bbox_inches='tight', facecolor='white'); plt.close(); print('saved FigureS6')


def figure_S7():
    # Figure S7: practice abandonment by NHS region, October 2025 to June 2026 (reads SAS_OUT/practice_summary,
    # ext_link and region).
    plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 8})
    ink = '#333333'; muted = '#777777'; BLUE = '#2f6db3'; RED = '#c8402a'; LGRAY = '#c9ced4'
    NAME = {'Y56': 'London', 'Y58': 'South West', 'Y59': 'South East', 'Y60': 'Midlands', 'Y61': 'East of England',
            'Y62': 'North West', 'Y63': 'North East and Yorkshire'}

    s = pd.read_sas(os.path.join(SAS_OUT, 'practice_summary.sas7bdat'), encoding='latin1')
    e = pd.read_sas(os.path.join(SAS_OUT, 'ext_link.sas7bdat'), encoding='latin1')[['practice_code', 'region_code']]
    reg = pd.read_sas(os.path.join(SAS_OUT, 'region.sas7bdat'), encoding='latin1').set_index('region_name')['raw']
    s = s[(s.inbound_stablewin >= 1000) & s.lat.notna()].copy()
    s['ab'] = 100 * s.abandoned_stablewin / s.inbound_stablewin
    s = s.merge(e, left_on='practice', right_on='practice_code', how='left')
    s['region'] = s.region_code.map(NAME)
    assert len(s) == 5049 and s.region.notna().all(), (len(s), s.region.isna().sum())
    lo, hi = np.percentile(s.ab, [20, 80])
    order = reg.sort_values().index.tolist()          # London (lowest 21 month rate) first
    CAP = 50
    rng = np.random.default_rng(20261016)
    fig, ax = plt.subplots(figsize=(9.6, 4.6))
    for i, r in enumerate(order[::-1]):
        v = s.loc[s.region == r, 'ab'].values
        y = i + rng.uniform(-0.28, 0.28, len(v))
        col = np.where(v <= lo, BLUE, np.where(v >= hi, RED, LGRAY))
        vc = np.minimum(v, CAP)
        ax.scatter(vc, y, s=4, c=col, alpha=0.75, linewidths=0, zorder=2)
        q1, med, q3 = np.percentile(v, [25, 50, 75])
        ax.plot([q1, q3], [i, i], color=ink, lw=2.2, zorder=3, solid_capstyle='butt')
        ax.plot([med, med], [i - 0.33, i + 0.33], color=ink, lw=1.6, zorder=3)
        ax.plot(reg[r], i, marker='D', ms=4.5, mfc='white', mec=ink, mew=1.0, zorder=4)
        nb, nw = int((v <= lo).sum()), int((v >= hi).sum())
        over = int((v > CAP).sum())
        extra = f'; {over} above {CAP}%' if over else ''
        ax.text(CAP + 1.2, i, f'n={len(v)}; best fifth {nb}, worst fifth {nw}{extra}', va='center', fontsize=7.4, color=ink)
    ax.set_yticks(range(len(order))); ax.set_yticklabels(order[::-1], fontsize=8.2)
    ax.axvline(lo, color=BLUE, lw=0.8, ls=':'); ax.axvline(hi, color=RED, lw=0.8, ls=':')
    ax.set_xlim(0, CAP); ax.set_ylim(-0.6, len(order) - 0.4)
    ax.set_xlabel('Abandoned calls, % of inbound calls (practice rate, October 2025 to June 2026)', fontsize=8.5)
    for sp in ('top', 'right', 'left'): ax.spines[sp].set_visible(False)
    ax.tick_params(axis='y', length=0); ax.grid(axis='x', color='#eeeeee', lw=0.7); ax.set_axisbelow(True)
    h = [Line2D([], [], marker='o', ls='', color=BLUE, ms=4, label=f'Best fifth (≤{lo:.1f}%)'),
         Line2D([], [], marker='o', ls='', color=RED, ms=4, label=f'Worst fifth (≥{hi:.1f}%)'),
         Line2D([], [], marker='o', ls='', color=LGRAY, ms=4, label='Middle three fifths'),
         Line2D([], [], color=ink, lw=2.2, label='Interquartile range; tick = median'),
         Line2D([], [], marker='D', ls='', mfc='white', mec=ink, ms=4.5, label='Regional call weighted rate, 21 months')]
    ax.legend(handles=h, loc='lower center', bbox_to_anchor=(0.5, 1.0), ncol=3, frameon=False, fontsize=7.4)
    plt.tight_layout(); plt.savefig(os.path.join(FIGS, 'FigureS7.png'), dpi=400, bbox_inches='tight', facecolor='white'); plt.close()
    print('saved FigureS7')


def figure_S8():
    # Figure S8: deprivation and change (panel A across the top, B and C below). Panel A reads SAS_OUT/practice_summary; its rate ratio labels are typed in
    # from output/TS1_tableS1.txt (panel 3). Panels B and C are typed in from the main text and
    # output/TS9_tableS9.txt (see README.md, Figures).
    B = SAS_OUT+'/'
    OUT = FIGS
    ink='#333333'; muted='#777777'
    BLUE='#2f6db3'; ORANGE='#d9641e'; GRAY='#9aa0a6'; PURPLE='#7b5ea7'
    RED='#c8402a'; LGRAY='#c9ced4'; GREEN='#3d8a5a'; LBLUE='#9fbbe0'
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':8,'axes.titlesize':9,'axes.labelsize':8.5,
                         'xtick.labelsize':8,'ytick.labelsize':8,'legend.fontsize':8})
    FS_ANN=7.5
    def despine(ax, grid='y'):
        for s in ['top','right']: ax.spines[s].set_visible(False)
        if grid: ax.grid(axis=grid, color='#eeeeee', lw=0.7)
        ax.set_axisbelow(True); ax.tick_params(labelsize=8, color=muted)
    def title(ax, t): ax.set_title(t, loc='left', color=ink, fontweight='bold', pad=8)

    ps = pd.read_sas(B+'practice_summary.sas7bdat', encoding='latin1')
    ps['A']=ps.abandoned_stablewin/ps.inbound_stablewin*100
    ps['B']=(ps.abandoned_stablewin+ps.callback_req_stablewin)/ps.inbound_stablewin*100
    ps['W']=(ps.abandoned_stablewin+ps.callback_req_stablewin+ps.menu_stablewin)/ps.inbound_stablewin*100
    ge=ps.groupby('pw_imd_decile_1poorest')[['A','B','W']].mean()
    ease=pd.Series([57.2,60.4,61.1,61.0,61.3,63.0,62.6,64.1,63.8,63.5], index=range(1,11))
    COH=[('In the collection from October to December 2024 (n=2918)',(55.9,59.3,62.6),BLUE),
         ('Entered January to September 2025 (n=1265)',(54.7,57.6,61.6),'#4a7fc0'),
         ('Entered October 2025 or later (n=866)',(53.7,56.4,60.1),LBLUE),
         ('Never in the collection (n=1092)',(52.3,55.2,58.3),GRAY)]

    fig=plt.figure(figsize=(11.6,8.8), dpi=400); gs=fig.add_gridspec(2,2, hspace=0.42, wspace=0.26)
    ax=fig.add_subplot(gs[0,:]); xd=np.arange(1,11)
    for col,c,name,rr in [('W',GREEN,'Total non-connection','RR 1.06 (1.01 to 1.11)'),
                          ('B',PURPLE,'Real time non-connection','RR 1.14 (1.04 to 1.24)'),
                          ('A',ORANGE,'Abandonment (official)','RR 1.24 (1.13 to 1.36)')]:
        ax.plot(xd, ge[col], color=c, lw=2, marker='o', ms=4.5, label=f'{name}; {rr}')
    ax.set_xticks(xd); ax.set_xticklabels(['1\nmost\ndeprived','2','3','4','5','6','7','8','9','10\nleast\ndeprived'],fontsize=8)
    ax.set_xlim(0.6,10.4); ax.set_ylim(0,52); ax.set_ylabel('% of calls (mean of practice rates)')
    ax.set_xlabel('Patient weighted IMD decile (IoD 2025). RR: decile 1 v 10, bootstrap 95% CI')
    ax.legend(frameon=False, loc='center right', fontsize=7.2); despine(ax)
    title(ax,'A  Failure by deprivation of the population served')

    ax=fig.add_subplot(gs[1,0]); cols=[RED if d_==1 else LGRAY for d_ in xd]
    ax.bar(xd, ease.values, 0.62, color=cols)
    for d_,v_ in zip(xd, ease.values): ax.text(d_, v_+0.8, f'{v_:.1f}', ha='center', fontsize=7, color=ink)
    ax.set_ylim(40,70); ax.set_xticks(xd); ax.set_xticklabels(['1\nmost\ndeprived','2','3','4','5','6','7','8','9','10\nleast\ndeprived'],fontsize=8)
    ax.set_ylabel('% of patients finding phone contact easy, 2026'); despine(ax)
    title(ax,'B  What patients report, by the same deciles')

    ax=fig.add_subplot(gs[1,1])
    for name,vals,c in COH:
        ax.plot([2024,2025,2026], vals, color=c, lw=2, marker='o', ms=4.5, label=name)
        ax.text(2026.06, vals[-1], f'+{vals[-1]-vals[0]:.1f}', fontsize=FS_ANN, color=c, va='center', fontweight='bold')
    ax.set_xticks([2024,2025,2026]); ax.set_xlim(2023.8,2026.35); ax.set_ylim(50,68)
    ax.set_ylabel('% of patients finding phone contact easy'); ax.legend(frameon=False, loc='upper left', fontsize=7); despine(ax)
    title(ax,'C  Reported ease by year and entry cohort')

    plt.savefig(f'{OUT}/FigureS8.png', bbox_inches='tight', facecolor='white'); plt.close()
    print('saved FigureS8')


def figure_S9():
    # Figure S9: share of calls diverted to a callback by deprivation decile (reads SAS_OUT/practice_month).
    B=SAS_OUT+'/'; OUT=FIGS
    ink='#333333'; muted='#777777'; PURPLE='#7b5ea7'; LGRAY='#c9ced4'
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':8,'axes.titlesize':9,'axes.labelsize':8.5,
                         'xtick.labelsize':8,'ytick.labelsize':8,'legend.fontsize':8})
    pm=pd.read_sas(B+'practice_month.sas7bdat',encoding='latin1')
    o=pm[(pm.cbt_observed==1)&pm.pw_imd_decile_1poorest.notna()]
    g=o.groupby('practice_code').agg(decile=('pw_imd_decile_1poorest','max'),
                                     ever=('cbt005_cb_requested',lambda x:(x.fillna(0)>0).any()))
    t=g.groupby('decile').ever.agg(['sum','count']); t['pct']=100*t['sum']/t['count']
    assert (t.loc[1.0,'sum'],t.loc[1.0,'count'])==(386,451), t.loc[1.0]
    assert (t.loc[10.0,'sum'],t.loc[10.0,'count'])==(516,544), t.loc[10.0]
    dec=t.index.astype(int).values; pct=t.pct.values
    fig,ax=plt.subplots(figsize=(9.2,3.9))
    ax.bar(dec,pct,color=[PURPLE if d==1 else LGRAY for d in dec],width=0.72)
    ax.axhline(pct[-1],color=muted,ls=':',lw=1,zorder=1.5)
    for x,v in zip(dec,pct):   # values in bold inside the top of each bar, clear of the dotted line
        ax.text(x,v-2.0,'%.1f'%v,ha='center',va='top',fontsize=8,fontweight='bold',color=('white' if x==1 else ink),zorder=3)
    ax.set_ylim(0,105); ax.set_xticks(range(1,11))
    ax.set_xticklabels(['1\nmost\ndeprived']+[str(i) for i in range(2,10)]+['10\nleast\ndeprived'])
    ax.set_ylabel('% of practices ever recording callback use')
    ax.set_xlabel('Patient weighted deprivation decile (English indices of deprivation 2025)')
    for s in ['top','right']: ax.spines[s].set_visible(False)
    ax.grid(axis='y',color='#eeeeee',lw=0.7); ax.set_axisbelow(True); ax.tick_params(labelsize=8,color=muted)
    plt.tight_layout(); plt.savefig(f'{OUT}/FigureS9.png',dpi=400,bbox_inches='tight',facecolor='white'); plt.close()
    print('saved FigureS9')


FIGURES = [figure_1, figure_2, figure_3, figure_S1, figure_S2, figure_S3, figure_S4, figure_S5, figure_S6, figure_S7, figure_S8, figure_S9]

if __name__ == '__main__':
    for draw in FIGURES:
        matplotlib.rc_file_defaults(); plt.close('all')
        draw(); print(draw.__name__, 'done')
