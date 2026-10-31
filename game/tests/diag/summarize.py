#!/usr/bin/env python3
"""Fasst Diagnose-CSVs zusammen. Aufruf: summarize.py <out_dir> [<out_dir2>]"""
import csv, sys, statistics as st, os

def load(d, n):
    p = os.path.join(d, n + '.csv')
    if not os.path.exists(p): return None
    return [r for r in csv.DictReader(open(p)) if r['phase'] == 'man']

def f(r, k): return float(r[k])

def win(rows, lo, hi): return [r for r in rows if lo <= f(r, 't') < hi]

def metrics(d):
    m = {}
    for n in ['a_arc_mouse60', 'a_arc_mouse30', 'a_arc_mouseflick', 'a_arc_kb']:
        r = load(d, n)
        if not r: continue
        w = win(r, 0.5, 3.0)
        g = [f(x, 'g') for x in w]
        e = [f(x, 'elev_cmd') for x in w]
        flips = sum(1 for i in range(1, len(e)) if abs(e[i] - e[i-1]) > 0.15)
        m[n] = dict(aoa_max=max(f(x, 'aoa_deg') for x in r[:180]), aoa_mean=st.mean(f(x, 'aoa_deg') for x in w),
                    g_mean=st.mean(g), g_sd=st.pstdev(g), stall=max(f(x, 'stall_amount') for x in r[:180]),
                    elev_jumps=flips)
    for n in ['a_real_kb', 'a_real_stick']:
        r = load(d, n)
        if not r: continue
        w = r[:180]
        m[n] = dict(q_max=max(f(x, 'q_rate_dps') for x in w), aoa_max=max(f(x, 'aoa_deg') for x in w),
                    g_max=max(f(x, 'g') for x in w), stall=max(f(x, 'stall_amount') for x in w))
    for n in ['c_arc_kb', 'c_arc_mouseslow']:
        r = load(d, n)
        if not r: continue
        # niedrigste Fahrt, bei der noch g >= 0.95 und Steigen >= -1 m/s (rollendes 1-s-Mittel)
        best = None
        for i in range(60, len(r)):
            seg = r[i-60:i]
            if st.mean(f(x, 'g') for x in seg) >= 0.95 and f(r[i], 'pitch_deg') < 25 and f(r[i], 'pitch_deg') > -10:
                v = f(r[i], 'speed_kmh')
                best = v if best is None else min(best, v)
        m[n] = dict(min_v=min(f(x, 'speed_kmh') for x in r), aoa_max=max(f(x, 'aoa_deg') for x in r),
                    stall=max(f(x, 'stall_amount') for x in r), pitch_max=max(f(x, 'pitch_deg') for x in r))
    for v in [200, 230, 260, 290, 320]:
        r = load(d, 'd_real_climb%d' % v)
        if not r: continue
        w = [x for x in r if f(x, 't') > 20]
        m['climb%d' % v] = dict(vs=st.mean(f(x, 'vs') for x in w), v=st.mean(f(x, 'speed_kmh') for x in w))
    return m

ds = sys.argv[1:]
res = [metrics(d) for d in ds]
keys = sorted(set().union(*[r.keys() for r in res]))
for k in keys:
    for d, r in zip(ds, res):
        if k in r:
            print('%-20s %-14s %s' % (k, os.path.basename(d.rstrip('/')), '  '.join('%s=%.2f' % kv for kv in r[k].items())))
