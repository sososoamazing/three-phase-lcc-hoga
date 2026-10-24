"""Read-only evidence analysis. Standard library only; no simulation or fitting."""
from pathlib import Path
import csv, json, math, hashlib, zipfile, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / '06_reports'
OUT = REPORT / 'accuracy_analysis'
DATA = OUT / 'data'
DATA.mkdir(parents=True, exist_ok=True)
def read(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))
def write(name, rows):
    with (DATA/name).open('w', encoding='utf-8-sig', newline='') as f:
        w=csv.DictWriter(f, fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def f(r,k): return float(r[k])
def key(r): return (int(float(r['Vo'])),int(float(r['fs'])))
P=read(REPORT/'Point_Results.csv'); E=read(REPORT/'Point_Errors.csv')
ports=read(REPORT/'Port_Metrics.csv')
by={(r['model'],*key(r)):r for r in P}
pb={(r['model'],*key(r)):r for r in ports}
assert len(P)==len(by)==80
models=['HOGA','EDF','FHA']
sets={m:{key(r) for r in P if r['model']==m and r['converged']=='1'} for m in ['REFERENCE']+models}
common=set.intersection(*sets.values());assert len(common)==20
ref={key(r):r for r in P if r['model']=='REFERENCE'}
ccm={k for k in common if f(ref[k],'blocked_fraction')<=1e-5};assert len(ccm)==16
selection=[]
for k in sorted(common):
    row={'Vo':k[0],'fs':k[1],'reference':'EVENT_ODE','CCM':int(k in ccm),
         'blocked_fraction':f(ref[k],'blocked_fraction'),'Io_reference_A':f(ref[k],'Io')}
    for m in models:row[m+'_valid']=int(k in sets[m])
    selection.append(row)
write('common_point_membership.csv',selection)
calc=[]
for k in sorted(common):
    for m in models:
        a=by[m,*k];b=ref[k];pa=pb[m,*k];pr=pb['REFERENCE',*k]
        old=next(r for r in E if r['reference']=='EVENT_ODE' and r['model']==m and key(r)==k)
        rms=[abs(f(pa,'Irms_'+p)-f(pr,'Irms_'+p)) for p in 'ABC']
        peak=[abs(f(pa,'Ipeak_'+p)-f(pr,'Ipeak_'+p)) for p in 'ABC']
        edges=[c for c in pa if c.startswith('gate_')]
        de=[f(pa,c)-f(pr,c) for c in edges]
        row={'model':m,'Vo':k[0],'fs':k[1],'outside_CCM':int(k not in ccm),
             'Io_reference_A':f(b,'Io'),'Io_model_A':f(a,'Io'),'Io_error_A':f(a,'Io')-f(b,'Io'),
             'Io_relative_percent':100*(f(a,'Io')/f(b,'Io')-1) if abs(f(b,'Io'))>1e-9 else '',
             'Irms_MAE_A':sum(rms)/3,'Irms_max_abs_A':max(rms),
             'Ipeak_MAE_A':sum(peak)/3,'Ipeak_max_abs_A':max(peak),
             'wave_NRMSE_Ibase':f(old,'wave_NRMSE_Ibase'),'wave_max_abs_A':f(old,'wave_max_abs_A'),
             'gate_current_MAE_A':sum(map(abs,de))/len(de),'gate_current_max_abs_A':max(map(abs,de))}
        for c in ['Io_error_A','Irms_MAE_A','Irms_max_abs_A','Ipeak_MAE_A','Ipeak_max_abs_A']:
            assert abs(row[c]-f(old,c))<1e-10,(m,k,c)
        calc.append(row)
write('point_metrics_recomputed.csv',calc)
stats=[]
for scope,keys in [('CCM',ccm),('OUTSIDE_TARGET_CCM',common-ccm),('ALL',common)]:
    for m in models:
        a=[r for r in calc if r['model']==m and (r['Vo'],r['fs']) in keys]
        stats.append({'scope':scope,'model':m,'points':len(a),
          'Io_MAE_A':sum(abs(r['Io_error_A']) for r in a)/len(a),
          'Io_max_abs_A':max(abs(r['Io_error_A']) for r in a),
          'Io_NRMSE_1A':math.sqrt(sum(r['Io_error_A']**2 for r in a)/len(a)),
          'Irms_MAE_A':sum(r['Irms_MAE_A'] for r in a)/len(a),
          'Ipeak_MAE_A':sum(r['Ipeak_MAE_A'] for r in a)/len(a),
          'wave_NRMSE_percent':100*math.sqrt(sum(r['wave_NRMSE_Ibase']**2 for r in a)/len(a)),
          'gate_current_MAE_A':sum(r['gate_current_MAE_A'] for r in a)/len(a),
          'gate_current_max_abs_A':max(r['gate_current_max_abs_A'] for r in a)})
write('common_scope_statistics.csv',stats)
maxima=[]
for m in models:
    a=[r for r in calc if r['model']==m]
    for metric in ['Io_error_A','Irms_MAE_A','Ipeak_MAE_A','wave_NRMSE_Ibase','gate_current_max_abs_A']:
        r=max(a,key=lambda x:abs(x[metric]))
        maxima.append({'model':m,'metric':metric,'Vo':r['Vo'],'fs':r['fs'],'value':r[metric]})
write('worst_points.csv',maxima)
wins=[]
for k in sorted(common):
    a=[r for r in calc if (r['Vo'],r['fs'])==k]
    for metric in ['Io_error_A','Irms_MAE_A','Ipeak_MAE_A','wave_NRMSE_Ibase']:
        v=min(abs(r[metric]) for r in a)
        winners=[r['model'] for r in a if abs(abs(r[metric])-v)<=1e-12]
        wins.append({'Vo':k[0],'fs':k[1],'metric':metric,'winners':'|'.join(winners)})
write('point_rankings.csv',wins)
voltage=[]
for k in sorted(k for k in common if k[1]==280000):
    row={'Vo':k[0],'Io_REFERENCE_A':f(ref[k],'Io'),'blocked_fraction':f(ref[k],'blocked_fraction')}
    for m in models:
        a=next(r for r in calc if r['model']==m and (r['Vo'],r['fs'])==k)
        row['Io_'+m+'_A']=a['Io_model_A'];row['error_'+m+'_A']=a['Io_error_A']
    voltage.append(row)
write('voltage_characteristics.csv',voltage)

# Recompute the displayed reference spectrum from exported real waveforms.
spectra=[]
for v in [100,400,800]:
    path=DATA/f'wave_REFERENCE_V{v}.csv'
    if not path.is_file():continue
    rows=read(path);n=len(rows);y=[float(r['iA_A']) for r in rows]
    for h in [1,5,7,11,13,31]:
        coefficient=sum(y[k]*complex(math.cos(-2*math.pi*h*k/n),math.sin(-2*math.pi*h*k/n)) for k in range(n))/n
        spectra.append({'Vo':v,'fs':280000,'phase':'A','harmonic':h,'peak_amplitude_A':2*abs(coefficient)})
if spectra:write('reference_spectrum_selected.csv',spectra)

# Model provenance is read from the supplied SLX, never modify it.
slx=ROOT.parent/'MATLAB_PRJ/three_phase/simulink/ideal_three_phase_LCC.slx'
snap={'path':str(slx),'sha256':hashlib.sha256(slx.read_bytes()).hexdigest(),'callbacks':[],'selected_blocks':[]}
with zipfile.ZipFile(slx) as z:
    for name in z.namelist():
        if not name.endswith('.xml'):continue
        try: tree=ET.fromstring(z.read(name))
        except ET.ParseError:continue
        for el in tree.iter('P'):
            if el.get('Name')=='InitFcn':snap['callbacks'].append(el.text)
        for b in tree.iter('Block'):
            if b.get('SID') in ['270','273','279','280','286','289','294']:
                snap['selected_blocks'].append({'xml':name,'name':b.get('Name'),'SID':b.get('SID'),
                    'parameters':{p.get('Name'):p.text for p in b.iter('P')}})
(OUT/'ideal_model_readonly_inspection.json').write_text(json.dumps(snap,ensure_ascii=False,indent=2),encoding='utf-8')
summary={'common_points':len(common),'CCM':len(ccm),'non_CCM':len(common-ccm),'stats':stats,'maxima':maxima,
         'exceptions_to_HOGA_win':[r for r in wins if r['winners']!='HOGA'],
         'voltage':voltage,'input_model_callbacks':snap['callbacks']}
(OUT/'analysis_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
