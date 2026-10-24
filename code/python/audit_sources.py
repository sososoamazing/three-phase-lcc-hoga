"""Fresh read-only SLX connectivity audit, source hashes and local literature text."""
from pathlib import Path
import hashlib, json, zipfile, xml.etree.ElementTree as ET
from pypdf import PdfReader

root=Path(__file__).resolve().parents[1]
project=root.parent
source=project/'MATLAB_PRJ/three_phase/simulink/three_phase_LCC.slx'
out=root/'00_audit/data'
z=zipfile.ZipFile(source)
r=ET.fromstring(z.read('simulink/systems/system_root.xml'))
blocks={b.get('SID'): b for b in r.findall('Block')}
parent={}
def find(a):
    parent.setdefault(a,a)
    if parent[a]!=a: parent[a]=find(parent[a])
    return parent[a]
def union(a,b): parent[find(a)]=find(b)
connections=[]
for line in r.findall('Line'):
    if line.get('LineType')!='Connection': continue
    ends=[p.text for p in line.iter('P') if p.get('Name') in ('Src','Dst')]
    connections.append(ends)
    for p in ends[1:]: union(ends[0],p)
for sid,b in blocks.items():
    if b.get('Name','').startswith('Current Sensor'):
        union(sid+'#lconn:1',sid+'#rconn:2')
nets={}
for port in list(parent): nets.setdefault(find(port),[]).append(port)
net_list=list(nets.values())
net_of={p:i for i,net in enumerate(net_list) for p in net}
params=[]
for sid,b in blocks.items():
    params.append({'sid':sid,'name':b.get('Name'),'type':b.get('BlockType'),
                   'parameters':{p.get('Name'):p.text for p in b.findall('P')+b.findall('InstanceData/P')}})
transformers=[p for p in params if p['name'].startswith('Ideal Transformer')]
caps=[p for p in params if p['parameters'].get('c')=='Cp']
def endpoints(p,ports): return [net_of.get(p['sid']+'#'+q) for q in ports]
primary=[endpoints(p,['lconn:1','lconn:2']) for p in transformers]
secondary=[endpoints(p,['rconn:1','rconn:2']) for p in transformers]
cp=[endpoints(p,['lconn:1','rconn:1']) for p in caps]
ground=[endpoints(p,['lconn:1'])[0] for p in params if p['name']=='Electrical Reference']
tests={
 'three_transformers':len(primary)==3,
 'delta_cycle':len(primary)==3 and {a for a,b in primary}=={b for a,b in primary} and len({a for a,b in primary})==3,
 'cp_parallel_primary':sorted(map(sorted,primary))==sorted(map(sorted,cp)),
 'secondary_star':len({b for a,b in secondary})==1 and len({a for a,b in secondary})==3,
 'neutral_floating':secondary[0][1] not in ground,
}
init=ET.fromstring(z.read('simulink/blockdiagram.xml')).find(".//P[@Name='InitFcn']").text
report={'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'checks':tests,
        'primary':primary,'secondary':secondary,'cp':cp,'ground':ground,'init_fcn':init,'nets':net_list,'blocks':params}
(out/'fresh_topology.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
paths=[source]+list((project/'MATLAB_PRJ/three_phase/hoga_audit_v2_20261014/src').glob('*.m'))+list((project/'MATLAB_PRJ/three_phase/hoga_audit_v2_20261014/legacy').glob('*.m'))+list((project/'MATLAB_PRJ/three_phase/hoga_general_characteristics_20261020/scripts').glob('*.m'))
manifest=[{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in paths]
(out/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for pattern in ['High-Order_Generalized*pdf','*王子滕.pdf','Multimode_Constant*pdf']:
    for pdf in (project/'电容充电电源_参考文献').glob(pattern):
        if (root/'00_audit/sources'/f'{pdf.stem}.txt').exists(): continue
        doc=PdfReader(pdf)
        text='\n'.join(f'\n--- PDF page {i+1} ---\n'+p.extract_text() for i,p in enumerate(doc.pages))
        (root/'00_audit/sources'/f'{pdf.stem}.txt').write_text(text,encoding='utf-8')
print(json.dumps({'checks':tests,'init_fcn':init,'primary':primary,'secondary':secondary,'cp':cp},ensure_ascii=False))
assert all(tests.values()),tests
