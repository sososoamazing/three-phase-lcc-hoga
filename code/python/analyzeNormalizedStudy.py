"""Source-backed numerical analysis for the normalized HOGA study.

All drawing is done by MATLAB (scripts/plotPaperFigures.m). This script only
builds auditable tables, merges the 13 historical stage-A status rows whose raw
MAT files were lost during the phase-tag incident, and writes summary.json.

It never fills unresolved points, never treats an all-blocked periodic family as
proof of charging reachability and never converts a necessary commutation-current
polarity into a ZVS certificate.
"""
from pathlib import Path
import csv, hashlib, json, math, sys
from collections import Counter
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root.parents[2]/'LCC_HighVoltage_CCM_Study/_50V800V_dependencies/numeric_runtime'))
import numpy as np
from scipy.io import loadmat

def read(file):
    with file.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def write(name,rows):
    if not rows:return
    keys=list(dict.fromkeys(k for row in rows for k in row))
    with (root/'tables'/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=keys);w.writeheader();w.writerows(rows)
def yes(x):return str(x).lower() in ['1','true']
def num(x,default=math.nan):
    try:
        v=float(x)
        return v
    except (TypeError,ValueError):return default
def pointkey(r):return tuple(round(float(r[k]),6) for k in ['Vo_V','fn','k_delta'])
BOOL=['accepted','physical','order_pass','CCM','all_six_polarity','zvs_certified']
TEXT=['stage','status','error','node_class','raw_available','reason']
def parse(row):
    out={}
    for k,v in row.items():
        if k in TEXT:out[k]=v
        elif k in BOOL:out[k]=yes(v)
        else:out[k]=num(v)
    return out

# ---------------------------------------------------------------- raw-backed rows
raw=[parse(r) for r in read(root/'tables/all_solved_points.csv')]
for r in raw:r['raw_available']=True
unique={}
for r in raw:
    at=pointkey(r);old=unique.get(at)
    stage_rank={'A':0,'B':1,'C':2}
    rank=lambda v:(v['accepted'],v['H'] if math.isfinite(v['H']) else 0,stage_rank.get(v['stage'],0))
    if old is None or rank(r)>rank(old):unique[at]=r

# ------------------------------------------- historical rows without surviving raw
# The 13 first-attempt stage-A MAT files that were destroyed by the phase-tag defect
# are still missing. Their coordinates were later re-solved by stage B, so no unique
# point is lost, but the original attempt is not claimed to be retained.
history=[];superseded=0
receipt=json.loads((root/'audit/phase_tag_recovery/receipt.json').read_text(encoding='utf-8'))
lost_first=sorted(a['file'] for a in receipt['affected'] if a.get('replaced_first_unresolved_A_mat'))
for row in read(root/'tables/stage_A_initial_status.csv'):
    r=parse(row)
    if pointkey(r) in unique:
        superseded+=1
        continue
    r['raw_available']=False
    r['node_class']='historical_status_only'
    r['reason']='first A-stage failure MAT was replaced before the phase-tag defect was detected; state row only'
    history.append(r)
merged=list(unique.values())+history
merged.sort(key=lambda r:(r['k_delta'],r['fn'],r['Vo_V']))
out=[]
for r in merged:
    row=dict(r)
    row['accepted']=int(bool(r['accepted']));row['physical']=int(bool(r['physical']))
    row['order_pass']=int(bool(r['order_pass']));row['CCM']=int(bool(r['CCM']))
    row['all_six_polarity']=int(bool(r['all_six_polarity']));row['zvs_certified']=int(bool(r['zvs_certified']))
    row['raw_available']=int(bool(r['raw_available']))
    out.append(row)
write('all_solved_points_with_history.csv',out)
write('historical_status_merge_audit.csv',[dict(
    record_count_raw=len(raw),unique_raw=len(unique),historical_rows_total=len(read(root/'tables/stage_A_initial_status.csv')),
    historical_rows_superseded=superseded,historical_rows_appended=len(history),
    lost_first_attempt_A_mat=len(lost_first),
    lost_first_attempt_A_mat_files=' | '.join(lost_first),
    stage_A_raw_files=sum(1 for r in raw if r['stage']=='A'),
    stage_B_raw_files=sum(1 for r in raw if r['stage']=='B'),
    stage_C_raw_files=sum(1 for r in raw if r['stage']=='C'),
    note=('13 first-attempt stage-A raw MAT files were destroyed by the phase-tag defect and are still unavailable. '
          'Their coordinates were later re-solved in stage B, so no unique point is missing, but the original '
          'attempt is not claimed to be retained; the original state rows remain in stage_A_initial_status.csv.'))])

# ------------------------------------------------------------- characteristic domain
points=sorted(unique.values(),key=lambda r:(r['k_delta'],r['fn'],r['Vo_V']))
point_rows=[]
for r in points:
    row=dict(r)
    for k in BOOL:row[k]=int(bool(r[k]))
    row.pop('raw_available',None);row.pop('node_class',None);row.pop('reason',None)
    point_rows.append(row)
write('characteristic_domain.csv',point_rows)
valid=[r for r in points if r['accepted']]
charging=[r for r in valid if r['Io_A']>1e-8]
openfam=[r for r in valid if r['Io_A']<=1e-8]

# ------------------------------------------------------------------------ coverage
coverage=[]
for fn,k in sorted(set((r['fn'],r['k_delta']) for r in points)):
    selected=[r for r in points if abs(r['fn']-fn)<1e-6 and abs(r['k_delta']-k)<1e-6]
    coarse=[r for r in selected if abs(r['Vo_V']/50-round(r['Vo_V']/50))<1e-8]
    accepted=[r for r in coarse if r['accepted']]
    charge=[r for r in accepted if r['Io_A']>1e-8]
    coverage.append(dict(fn=fn,k_delta=k,coarse_points=len(coarse),accepted_coarse=len(accepted),
        charging_coarse=len(charge),open_coarse=sum(r['Io_A']<=1e-8 for r in accepted),
        unresolved_coarse=len(coarse)-len(accepted),all_17_coarse_charging=len(charge)==17,
        minimum_charging_V=min((r['Vo_V'] for r in charge),default=math.nan),
        maximum_charging_V=max((r['Vo_V'] for r in charge),default=math.nan)))
write('frequency_capacitance_coverage.csv',coverage)

# ----------------------------------------------------- output envelope versus fn
fn_summary=[]
for fn in sorted(set(r['fn'] for r in points)):
    sel=[r for r in charging if abs(r['fn']-fn)<1e-6 and abs(r['k_delta']-.2)<1e-6]
    if not sel:continue
    best=max(sel,key=lambda r:r['Io_A'])
    fn_summary.append(dict(fn=fn,charging_points=len(sel),maximum_Io_A=best['Io_A'],
        Vo_at_maximum_Io_V=best['Vo_V'],maximum_charging_Vo_V=max(r['Vo_V'] for r in sel),
        minimum_charging_Vo_V=min(r['Vo_V'] for r in sel),
        Io_at_400V_A=next((r['Io_A'] for r in sel if abs(r['Vo_V']-400)<1e-6),math.nan),
        Im_at_400V_A=next((r['Im_A'] for r in sel if abs(r['Vo_V']-400)<1e-6),math.nan),
        Io_at_800V_A=next((r['Io_A'] for r in sel if abs(r['Vo_V']-800)<1e-6),math.nan),
        maximum_Im_A=max(r['Im_A'] for r in sel)))
write('fn_output_envelope.csv',fn_summary)

# ------------------------------------------- maximum-output locus versus voltage
envelope=[]
for v in sorted(set(round(r['Vo_V'],6) for r in charging if abs(r['k_delta']-.2)<1e-6)):
    sel=[r for r in charging if abs(r['Vo_V']-v)<1e-6 and abs(r['k_delta']-.2)<1e-6]
    best=max(sel,key=lambda r:r['Io_A'])
    envelope.append(dict(Vo_V=v,sampled_count=len(sel),sampled_fn=[r['fn'] for r in sorted(sel,key=lambda r:r['fn'])],
        fn_at_maximum_Io=best['fn'],maximum_Io_A=best['Io_A'],Im_at_maximum_Io_A=best['Im_A'],
        Irms_at_maximum_Io_A=best['Irms_A'],lowest_sampled_fn=min(r['fn'] for r in sel),
        highest_sampled_fn=max(r['fn'] for r in sel),
        Io_at_lowest_fn_A=next(r['Io_A'] for r in sel if r['fn']==min(s['fn'] for s in sel)),
        Io_increases_with_fn=best['fn']>min(r['fn'] for r in sel)+1e-9))
write('maximum_io_envelope.csv',envelope)

# ------------------------------------------- capacitance ratio effect (fn = 1.4)
caps=[]
voltages=[50,100,200,300,400,500,600,700,800]
for k in [.1,.2,.35,.5,.8,1]:
    sel=[r for r in points if abs(r['k_delta']-k)<1e-6 and abs(r['fn']-1.4)<1e-6]
    charge=[r for r in sel if r['accepted'] and r['Io_A']>1e-8]
    row=dict(k_delta=k,k_star=3*k,Cp_delta_nF=k*135,fn_open_pole=math.sqrt(1+1/(3*k)),
        fn=1.4,solved=len(sel),accepted=sum(r['accepted'] for r in sel),charging=len(charge),
        open_family=sum(r['accepted'] and r['Io_A']<=1e-8 for r in sel),
        maximum_charging_Vo_V=max((r['Vo_V'] for r in charge),default=math.nan),
        maximum_Io_A=max((r['Io_A'] for r in charge),default=math.nan))
    for v in voltages:
        r=next((s for s in sel if abs(s['Vo_V']-v)<1e-6),None)
        row[f'Io_A_V{v}']=r['Io_A'] if r and r['accepted'] else math.nan
        row[f'Im_A_V{v}']=r['Im_A'] if r and r['accepted'] else math.nan
        row[f'Irms_A_V{v}']=r['Irms_A'] if r and r['accepted'] else math.nan
        row[f'status_V{v}']=r['status'] if r else 'NOT_RUN'
    caps.append(row)
write('capacitance_ratio_effect.csv',caps)

# --------------------------------------------------------------- crossing brackets
crossings=[]
for a,b in [(1.4,1.5),(1.4,1.6),(1.5,1.6)]:
    av={r['Vo_V']:r for r in charging if abs(r['k_delta']-.2)<1e-6 and abs(r['fn']-a)<1e-6}
    bv={r['Vo_V']:r for r in charging if abs(r['k_delta']-.2)<1e-6 and abs(r['fn']-b)<1e-6}
    shared=sorted(set(av)&set(bv));brackets=[]
    for v0,v1 in zip(shared,shared[1:]):
        d0=av[v0]['Im_A']-bv[v0]['Im_A'];d1=av[v1]['Im_A']-bv[v1]['Im_A']
        if d0*d1<=0:brackets.append((v0,v1,d0,d1))
    for v0,v1,d0,d1 in brackets:
        crossings.append(dict(fn_a=a,fn_b=b,k_delta=.2,Vo_lower_V=v0,Vo_upper_V=v1,
            Im_difference_lower_A=d0,Im_difference_upper_A=d1,
            status='SIGN_CHANGE_BETWEEN_VERIFIED_NODES; not interpolated root'))
    if not brackets:crossings.append(dict(fn_a=a,fn_b=b,k_delta=.2,status='NO_VERIFIED_SIGN_CHANGE_IN_COMMON_SAMPLED_DOMAIN'))
write('crossing_brackets.csv',crossings)

# --------------------------------------------------- sampled output / stress tradeoff
tradeoffs=[];pareto=[];gain=[]
for v in [100,200,400,600,800]:
    candidates=[r for r in charging if abs(r['Vo_V']-v)<1e-6 and abs(r['k_delta']-.2)<1e-6 and r['CCM']]
    for domain in ['CCM','CCM_AND_NECESSARY_POLARITY']:
        allowed=[r for r in candidates if domain=='CCM' or r['all_six_polarity']]
        if not allowed:continue
        for r in allowed:
            dominated=any(s['Io_A']>=r['Io_A'] and s['Im_A']<=r['Im_A'] and s['Irms_A']<=r['Irms_A']
                and (s['Io_A']>r['Io_A']+1e-8 or s['Im_A']<r['Im_A']-1e-8 or s['Irms_A']<r['Irms_A']-1e-8)
                for s in allowed)
            pareto.append(dict(Vo_V=v,domain=domain,fn=r['fn'],Io_A=r['Io_A'],Im_A=r['Im_A'],
                Irms_A=r['Irms_A'],nondominated=not dominated,zvs_certified=False))
        maximum=max(allowed,key=lambda r:r['Io_A'])
        for fraction in [.25,.5,.75]:
            target=maximum['Io_A']*fraction;eligible=[r for r in allowed if r['Io_A']>=target]
            best=min(eligible,key=lambda r:r['Irms_A'])
            tradeoffs.append(dict(Vo_V=v,domain=domain,relative_current_requirement=fraction,Io_requirement_A=target,
                fn_minimum_sampled_RMS=best['fn'],actual_Io_A=best['Io_A'],Im_A=best['Im_A'],Irms_A=best['Irms_A'],
                fn_maximum_output_current=maximum['fn'],maximum_Io_A=maximum['Io_A'],maximum_output_RMS_A=maximum['Irms_A'],
                RMS_reduction_percent=100*(1-best['Irms_A']/maximum['Irms_A']),
                interpretation='finite sampled set; necessary polarity is not ZVS certification; no hardware current/power limits'))
        gain.append(dict(Vo_V=v,domain=domain,sampled_points=len(allowed),
            fn_min=min(r['fn'] for r in allowed),fn_max=max(r['fn'] for r in allowed),
            Io_range_A=max(r['Io_A'] for r in allowed)-min(r['Io_A'] for r in allowed),
            Im_range_A=max(r['Im_A'] for r in allowed)-min(r['Im_A'] for r in allowed),
            Im_at_maximum_Io_A=maximum['Im_A'],minimum_sampled_Im_A=min(r['Im_A'] for r in allowed)))
write('pareto_points.csv',pareto);write('matched_requirement_tradeoffs.csv',tradeoffs)
write('frequency_freedom_by_voltage.csv',gain)

# --------------------------------------------------------------- switching records
validations=[]
for file in sorted((root/'validation').glob('*.mat')):
    d=loadmat(file,variable_names=['record','cfg'],simplify_cells=True)
    if 'record' not in d:continue
    record=d['record'];record['source_file']=file.name
    cfg=d['cfg'];record['max_step_s']=cfg['max_step_s'];record['cycles']=cfg['cycles']
    record['output_Co_scale']=cfg['output_Co_scale'] if 'output_Co_scale' in cfg else math.nan
    validations.append(record)
write('switching_validation_all.csv',validations)
accepted_val=[r for r in validations if bool(r.get('accepted',False))]
failed_val=[r for r in validations if not bool(r.get('accepted',False))]
def vmax(rows,key,finite_only=True):
    values=[r[key] for r in rows if key in r and math.isfinite(float(r[key]))]
    return max(values) if values else None
error_rows=[]
for r in validations:
    error_rows.append(dict(source_file=r['source_file'],Vo_V=r.get('Vo_V'),fn=r.get('fn'),k_delta=r.get('k_delta'),
        accepted=int(bool(r.get('accepted',False))),Io_error_percent=r.get('Io_error_percent'),
        Im_error_percent=r.get('Im_error_percent'),Irms_error_percent=r.get('Irms_error_percent'),
        wave_L2_error_percent=r.get('wave_L2_error_percent'),Vo_drift_percent=r.get('Vo_drift_percent'),
        periodic_change_percent=r.get('periodic_change_percent'),cycles=r.get('cycles')))
write('validation_error_summary.csv',error_rows)
convergence=[]
for r in validations:
    if not r['source_file'].endswith('_fine.mat'):continue
    coarse=next((s for s in validations if s['source_file']==r['source_file'].replace('_fine.mat','.mat')),None)
    if coarse:
        convergence.append(dict(Vo_V=r['Vo_V'],fn=r['fn'],k_delta=r['k_delta'],
            Io_difference_A=abs(r['Io_Simulink_A']-coarse['Io_Simulink_A']),
            Im_difference_percent=100*abs(r['Im_Simulink_A']/coarse['Im_Simulink_A']-1),
            Irms_difference_percent=100*abs(r['Irms_Simulink_A']/coarse['Irms_Simulink_A']-1),
            fine_cycles=r['cycles'],coarse_cycles=coarse['cycles']))
write('switching_numerical_convergence.csv',convergence)

# -------------------------------------------------------- recovery pass outcome
recovery=[r for r in raw if r['stage']=='C']
if recovery:
    rows_out=[]
    for r in sorted(recovery,key=lambda x:(x['fn'],x['k_delta'],x['Vo_V'])):
        rows_out.append(dict(Vo_V=r['Vo_V'],fn=r['fn'],k_delta=r['k_delta'],accepted=int(bool(r['accepted'])),
            status=r['status'],Io_A=r['Io_A'],Im_A=r['Im_A'],H=r['H'],
            attempt_count=r['attempt_count'],elapsed_s=r['elapsed_s'],error=str(r['error'])[:120]))
    write('recovery_outcome.csv',rows_out)
    solved_before={k for k,v in unique.items() if v['stage']!='C' and v['accepted']}
    summary_recovery=dict(attempted=len(recovery),accepted=sum(1 for r in recovery if r['accepted']),
        charging=sum(1 for r in recovery if r['accepted'] and r['Io_A']>1e-8),
        open_family=sum(1 for r in recovery if r['accepted'] and r['Io_A']<=1e-8),
        still_unresolved=sum(1 for r in recovery if not r['accepted']))
else:
    summary_recovery=dict(attempted=0,accepted=0,charging=0,open_family=0,still_unresolved=0)

# -------------------------------------------------------------------- source audit
manifest=json.loads((root/'audit/source_manifest.json').read_text(encoding='utf-8'))
mismatch=[]
for entry in manifest:
    source=Path(entry['source'])
    actual=hashlib.sha256(source.read_bytes()).hexdigest() if source.is_file() else 'MISSING'
    if actual!=entry['sha256']:mismatch.append(dict(source=str(source),expected=entry['sha256'],actual=actual))

summary=dict(
    record_count_raw=len(raw),record_count_with_history=len(out),
    unique_points=len(points),accepted_unique=len(valid),charging_unique=len(charging),
    open_periodic_family_unique=len(openfam),unresolved_unique=len(points)-len(valid),
    historical_status_only_rows=len(history),
    harmonic_orders=dict(Counter(int(r['H']) for r in valid)),
    max_Io_order_change_percent=100*max((r['Io_H_change'] for r in charging),default=0),
    max_Im_order_change_percent=100*max((r['Im_H_change'] for r in valid),default=0),
    max_Irms_order_change_percent=100*max((r['Irms_H_change'] for r in valid),default=0),
    max_peak_grid_refinement_percent=100*max((r['peak_grid_refinement'] for r in valid),default=0),
    simulation_cases=len(validations),simulation_accepted=len(accepted_val),simulation_failed=len(failed_val),
    max_Io_Simulink_error_percent=vmax(accepted_val,'Io_error_percent'),
    max_Im_Simulink_error_percent=vmax(accepted_val,'Im_error_percent'),
    max_Irms_Simulink_error_percent=vmax(accepted_val,'Irms_error_percent'),
    max_Im_Simulink_error_percent_all_records=vmax(validations,'Im_error_percent'),
    max_Io_Simulink_error_percent_all_records=vmax(validations,'Io_error_percent'),
    source_files_unchanged=len(manifest)-len(mismatch),source_mismatch=mismatch,
    recovery=summary_recovery,
    coverage=coverage,crossings=crossings)
def finite_json(value):
    if isinstance(value,float) and not math.isfinite(value):return None
    if isinstance(value,dict):return {k:finite_json(v) for k,v in value.items()}
    if isinstance(value,list):return [finite_json(v) for v in value]
    return value
(root/'summary.json').write_text(json.dumps(finite_json(summary),ensure_ascii=False,indent=2,allow_nan=False),encoding='utf-8')
print(json.dumps(finite_json({k:v for k,v in summary.items() if k not in ['coverage','crossings']}),ensure_ascii=False,indent=1))
