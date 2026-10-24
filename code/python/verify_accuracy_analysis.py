"""Independent arithmetic/artifact verification, without any model execution.
Reads original CSV and MATLAB-exported raw-result checks. Exports one CSV per
numbered report table, figure lineage, source hashes, and a machine QA receipt.
Requires Pillow and pypdf; pypdfium2 is optional for PDF preview.
"""
from pathlib import Path
import csv, hashlib, json, math, re
from PIL import Image, ImageOps, ImageDraw
from pypdf import PdfReader

R=Path(__file__).resolve().parent; ROOT=R.parent
OUT=R/'accuracy_analysis';DATA=OUT/'data';QA=OUT/'qa_previews'
QA.mkdir(exist_ok=True);(DATA/'tables').mkdir(exist_ok=True)
doc=(R/'HOGA_EDF_FHA_Accuracy_Analysis.md').read_text(encoding='utf-8')
def read(path):
    with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def dump(path,rows):
    with path.open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def key(x):return x['reference'],x['model'],int(float(x['Vo'])),int(float(x['fs']))
def close(a,b,tol=1e-10):assert abs(float(a)-float(b))<=tol,(a,b,tol)
errors=read(R/'Point_Errors.csv');eb={key(x):x for x in errors}
raw=read(DATA/'independent_raw_metric_check.csv')
assert len(raw)==69 and len(eb)==69 and {key(x) for x in raw}==set(eb)
fields=['Io_error_A','Irms_MAE_A','Irms_max_abs_A','Ipeak_MAE_A','Ipeak_max_abs_A','wave_NRMSE_Ibase','wave_max_abs_A']
maxdiff={field:max(abs(float(x[field])-float(eb[key(x)][field])) for x in raw) for field in fields}
assert max(maxdiff.values())<1e-10
point=read(R/'Point_Results.csv');pb={(x['model'],int(x['Vo']),int(x['fs'])):x for x in point}
assert len(pb)==len(point)==80 and all(x['converged']=='1' for x in point)
params=read(DATA/'saved_parameter_checks.csv')
assert len(params)==80 and all(r['passed']=='1' for r in params)
for r in params:
    for field,value in {'Vin':50,'Ls':4.7e-6,'Cs':135e-9,'Cp_delta':27e-9,'n_sp':4,'Rin':1e-3,'Vf_rect':.6}.items():close(r[field],value,1e-14)
membership=read(DATA/'common_point_membership.csv')
assert sum(int(x['CCM']) for x in membership)==16 and len(membership)==20
assert {(int(x['Vo']),int(x['fs'])) for x in membership if x['CCM']=='0'}=={(800,f) for f in [240000,260000,280000,320000]}

# Recompute all 24 legacy scope/model/reference aggregate records from point errors.
stats=read(R/'Error_Statistics.csv');statdiff=[]
for s in stats:
    a=[x for x in errors if x['reference']==s['reference'] and x['model']==s['model'] and x['valid']=='1']
    if s['scope']=='CCM':a=[x for x in a if x['outside_CCM']=='0']
    if s['scope']=='OUTSIDE_TARGET_CCM':a=[x for x in a if x['outside_CCM']=='1']
    if s['scope']=='VOLTAGE_SWEEP':a=[x for x in a if x['fs']=='280000']
    assert len(a)==int(s['valid_points'])
    v={'Io_MAE_A':sum(abs(float(x['Io_error_A'])) for x in a)/len(a),
       'Io_NRMSE_1A':math.sqrt(sum(float(x['Io_error_A'])**2 for x in a)/len(a)),
       'Io_max_abs_A':max(abs(float(x['Io_error_A'])) for x in a),
       'Irms_MAE_A':sum(float(x['Irms_MAE_A']) for x in a)/len(a),
       'Ipeak_MAE_A':sum(float(x['Ipeak_MAE_A']) for x in a)/len(a),
       'wave_NRMSE_Ibase':math.sqrt(sum(float(x['wave_NRMSE_Ibase'])**2 for x in a)/len(a))}
    for col,value in v.items():close(value,s[col]);statdiff.append(abs(value-float(s[col])))

# Independently integrate sampled error in Python for every displayed waveform pair.
ibase=50/math.sqrt(4.7e-6/135e-9);wavechecks=[]
for v in [100,400,800]:
    for reference,filetag in [('EVENT_ODE','REFERENCE'),('SIMULINK_FINE','SIMULINK')]:
        ref=read(DATA/f'wave_{filetag}_V{v}.csv');assert len(ref)==8192
        for model in ['HOGA','EDF','FHA']:
            a=read(DATA/f'wave_{model}_V{v}.csv');assert len(a)==8192
            total=0;maximum=0
            for x,y in zip(a,ref):
                close(x['tau'],y['tau'],1e-14)
                for col in ['iA_A','iB_A','iC_A']:
                    d=float(x[col])-float(y[col]);total+=d*d;maximum=max(maximum,abs(d))
            nrmse=math.sqrt(total/(8192*3))/ibase
            e=eb[reference,model,v,280000]
            close(nrmse,e['wave_NRMSE_Ibase']);close(maximum,e['wave_max_abs_A'])
            wavechecks.append({'reference':reference,'model':model,'Vo':v,'NRMSE':nrmse,'max_A':maximum})

# Parse tables, ensure Markdown column counts, and export one table per file.
tables={};lines=doc.splitlines();active=None;i=0
while i<len(lines):
    match=re.match(r'\*\*表([\dAB]+-\d+)\s',lines[i])
    if match:active=match.group(1)
    if lines[i].startswith('|'):
        assert active,'Unnumbered table'
        grid=[]
        while i<len(lines) and lines[i].startswith('|'):
            grid.append([c.strip() for c in lines[i].strip('|').split('|')]);i+=1
        width=len(grid[0]);assert all(len(r)==width for r in grid),(active,'table column mismatch')
        tables[active]=[grid[0]]+grid[2:]
        with (DATA/'tables'/f'Table_{active}.csv').open('w',encoding='utf-8-sig',newline='') as f:
            csv.writer(f).writerows(tables[active])
        active=None;continue
    i+=1
def rounded(cell,value):
    t=cell.replace('−','-').replace('*','');n=len(t.split('.')[-1]) if '.' in t else 0
    close(t,value,0.51*10**(-n)+1e-12)
for row in tables['3-1'][1:]:
    v=int(row[0].replace('*',''));ks=['REFERENCE','HOGA','EDF','FHA']
    for col,m in enumerate(ks,1):rounded(row[col],pb[m,v,280000]['Io'])
    for col,m,scale in [(5,'HOGA',1e6),(6,'EDF',1e3),(7,'FHA',1e3)]:
        rounded(row[col],float(eb['EVENT_ODE',m,v,280000]['Io_error_A'])*scale)
for row in tables['4-1'][1:]:
    v=int(row[0].replace('*',''));m='REFERENCE' if row[1]=='ODE' else row[1]
    for col,fld in [(2,'Irms'),(3,'Ipeak')]:rounded(row[col],pb[m,v,280000][fld])
    if m!='REFERENCE':
        e=eb['EVENT_ODE',m,v,280000]
        for col,fld,scale in [(4,'Irms_MAE_A',1),(5,'Ipeak_MAE_A',1),(6,'wave_NRMSE_Ibase',100)]:rounded(row[col],float(e[fld])*scale)
sb={(s['reference'],s['scope'],s['model']):s for s in stats}
for idx,fld,scale in [(1,'Io_MAE_A',1),(2,'Io_max_abs_A',1),(3,'Io_NRMSE_1A',1),(4,'Irms_MAE_A',1),(5,'Ipeak_MAE_A',1),(6,'wave_NRMSE_Ibase',100)]:
    for col,m in enumerate(['HOGA','EDF','FHA'],1):rounded(tables['6-1'][idx][col],float(sb['EVENT_ODE','CCM',m][fld])*scale)
for row in tables['6-2'][1:]:
    scope='ALL' if row[0].startswith('全部') else 'OUTSIDE_TARGET_CCM';s=sb['EVENT_ODE',scope,row[1]]
    for col,fld,scale in [(2,'Io_MAE_A',1),(3,'Io_max_abs_A',1),(4,'Irms_MAE_A',1),(5,'Ipeak_MAE_A',1),(6,'wave_NRMSE_Ibase',100)]:rounded(row[col],float(s[fld])*scale)
for row in tables['6-3'][1:]:
    s=sb['SIMULINK_FINE','ALL',row[0]]
    for col,fld,scale in [(1,'Io_MAE_A',1),(2,'Io_max_abs_A',1),(3,'Irms_MAE_A',1),(4,'Ipeak_MAE_A',1),(5,'wave_NRMSE_Ibase',100)]:rounded(row[col],float(s[fld])*scale)

def image_count(resources):
    if not resources:return 0
    total=0
    for o in resources.get('/XObject',{}).values():
        x=o.get_object()
        if x.get('/Subtype')=='/Image':total+=1
        if x.get('/Subtype')=='/Form':total+=image_count(x.get('/Resources'))
    return total
figures=[];figqa=[]
for alt,path in re.findall(r'!\[([^\]]+)\]\(([^)]+)\)',doc):
    number=re.search(r'图(\d+-\d+)',alt).group(1);png=(R/path).resolve();pdf=png.with_suffix('.pdf')
    assert png.is_file() and pdf.is_file();name=png.stem;reused='05_verification' in str(png)
    with Image.open(png) as im:
        dims=im.size;dpi=im.info.get('dpi');assert min(dims)>1000 and dpi and all(abs(x-300)<1 for x in dpi)
    reader=PdfReader(pdf);nimages=sum(image_count(p.get('/Resources')) for p in reader.pages)
    assert len(reader.pages)==1 and nimages==0
    if name.startswith('frequency_error'):source=f'accuracy_analysis/data/{name}.csv';filter_='Vo='+name.split('V')[-1]+', EVENT_ODE, five frequencies'
    elif name in ['voltage_rms_error','voltage_peak_error']:source='Point_Errors.csv';filter_='EVENT_ODE, fs=280000, all eight voltages'
    elif name.startswith('hoga_order') or name=='order_rms_error':source='Harmonic_Convergence.csv; ../00_audit/data/stage1_run02/original_V*_H*.mat';filter_='280000 Hz; H=1,3,5,7,9,15,31'
    elif name.startswith('voltage_Io'):source='Point_Results.csv; Point_Errors.csv; Simulink_Refinement.csv';filter_='fs=280000; 8 ODE points and 3 Simulink points (Io only)'
    else:
        v=re.search(r'_V(\d+)',name).group(1);source=f'accuracy_analysis/data/wave_*_V{v}.csv; ../05_verification/data/campaign/*_V{v}_f280000.mat; ../05_verification/data/simulink_V{v}_fine_integrated.mat';filter_=f'Vo={v}, fs=280000, same gate phase'
    figures.append({'figure':number,'caption':alt,'png':path,'pdf':path[:-4]+'.pdf','reused':int(reused),
                    'sources_relative_to_reports':source,'selection':filter_,
                    'MATLAB_renderer':'../05_verification/postprocess_comparison.m' if reused else 'plot_accuracy_analysis.m'})
    figqa.append({'figure':number,'png_dimensions':dims,'dpi':dpi,'pdf_pages':1,'raster_objects':nimages,
                  'pdf_extracted_text_length':sum(len(p.extract_text() or '') for p in reader.pages)})
assert len(figures)==28 and sum(f['reused'] for f in figures)==22
dump(OUT/'Figure_Sources.csv',figures)

# Compact raster previews for human visual inspection, not report deliverables.
for start in range(0,len(figures),6):
    group=figures[start:start+6];sheet=Image.new('RGB',(1680,math.ceil(len(group)/2)*620),'#eeeeee');draw=ImageDraw.Draw(sheet)
    for j,fig in enumerate(group):
        with Image.open((R/fig['png']).resolve()) as im:
            thumb=ImageOps.contain(im.convert('RGB'),(820,575))
            x=(j%2)*840+(840-thumb.width)//2;y=(j//2)*620+30
            sheet.paste(thumb,(x,y));draw.text(((j%2)*840+10,(j//2)*620+8),fig['figure']+' / '+Path(fig['png']).stem,fill='black')
    sheet.save(QA/f'contact_{start//6+1}.png')
try:
    import pypdfium2 as pdfium
    for fig in figures:
        if not fig['reused']:
            document=pdfium.PdfDocument(str((R/fig['pdf']).resolve()));page=document[0]
            page.render(scale=1.2).to_pil().save(QA/(Path(fig['pdf']).stem+'_pdf.png'));page.close();document.close()
    pdf_rendered=6
except ImportError:pdf_rendered=0

original=read(ROOT/'05_verification/data/campaign/point_summary.csv')
assert sum(r['converged']=='1' for r in original if r['model']=='HOGA')==18
assert len(read(DATA/'order_status.csv'))==28 and all(x['physical_guard_pass']=='1' for x in read(DATA/'order_status.csv'))
assert len(read(R/'Convergence_Validation.csv'))==4
assert all(x['H31_acceptance']=='PASS' for x in read(R/'Convergence_Validation.csv'))
assert len(re.findall(r'^## 第[一二三四五六七]章',doc,re.M))==7
assert doc.count('$$')%2==0 and doc.count('```')%2==0

# Original sources stay unchanged against the pre-existing source manifest.
original_manifest=json.loads((ROOT/'00_audit/data/source_manifest.json').read_text(encoding='utf-8-sig'))
source_checks=[]
for entry in original_manifest:
    p=Path(entry['path']);actual=hashlib.sha256(p.read_bytes()).hexdigest()
    assert actual==entry['sha256'],str(p)
    source_checks.append({'file':str(p),'unchanged':True})
files=set(R.glob('*.csv')) | set(ROOT.glob('01_common/*.m')) | set(ROOT.glob('03_EDF/*.m')) | set(ROOT.glob('04_FHA/*.m'))
files |= set(ROOT.glob('00_audit/data/stage1_run02/*.mat')) | set(ROOT.glob('05_verification/data/campaign/*.mat')) | set(ROOT.glob('05_verification/data/recovery/*.mat'))
files |= set(ROOT.glob('05_verification/data/simulink_*_raw.mat')) | set(ROOT.glob('05_verification/data/simulink_*_integrated.mat'))
files |= set(DATA.glob('*.csv')) | set(DATA.glob('tables/*.csv')) | {R/'HOGA_EDF_FHA_Accuracy_Analysis.md',OUT/'Figure_Sources.csv'}
files |= {R/n for n in ['plot_accuracy_analysis.m','analyze_accuracy_data.py','verify_accuracy_analysis.py']}
files |= {ROOT.parent/'MATLAB_PRJ/three_phase/simulink/ideal_three_phase_LCC.slx',ROOT/'05_verification/models/lcc3_comparison.slx'}
for fig in figures:files|={(R/fig['png']).resolve(),(R/fig['pdf']).resolve()}
manifest=[{'path':str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p),'bytes':p.stat().st_size,
           'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)]
(OUT/'Source_Manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
result={'status':'PASS','scope':'independent postprocessing, not new model simulation',
        'raw_comparisons':69,'raw_metric_max_difference':maxdiff,'aggregate_rows_checked':len(stats),
        'aggregate_max_difference':max(statdiff),'independently_recomputed_waveform_pairs':len(wavechecks),
        'common_points':20,'common_CCM':16,'non_CCM':4,'initial_HOGA_pass':18,'final_HOGA_pass':20,
        'order_points':28,'strict_H31_points':4,'numbered_tables':len(tables),'embedded_figures':28,
        'reused_figures':22,'new_figures':6,'source_manifest_entries':len(manifest),
        'original_source_integrity':source_checks,'figures':figqa,'new_pdfs_rendered':pdf_rendered,
        'visual_review':'See Visual_Review.json; automated file checks do not imply visual acceptance',
        'saved_parameter_records_checked':len(params),
        'matlab_checkcode':json.loads((OUT/'matlab_checkcode.json').read_text(encoding='utf-8')),
        'model_tests':'30 prior tests retained, not rerun in this report task'}
(OUT/'QA_Check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
broken=[];links=re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',doc)
for link in links:
    if '://' in link or link.startswith('#'):continue
    target=(R/link.split('#')[0]).resolve()
    if not target.exists():broken.append(link)
assert not broken,broken
result['local_links_checked']=len(links);result['broken_links']=[]
(OUT/'QA_Check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ['original_source_integrity','figures']},ensure_ascii=False,indent=2))
