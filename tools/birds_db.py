import json,re
# Parse pfQuest data files as text (never executed)
def parse_units(path):
    units={}; cur=None; incoords=False
    for line in open(path,encoding='utf-8'):
        m=re.match(r'^  \[(\d+)\] = \{',line)
        if m: cur=int(m.group(1)); units[cur]=[]; continue
        m=re.match(r'^\s+\[\d+\] = \{ ([\d.]+), ([\d.]+), (\d+), (\d+) \},',line)
        if m and cur is not None: units[cur].append(int(m.group(3)))
    return units
def parse_names(path):
    d={}
    for line in open(path,encoding='utf-8'):
        m=re.match(r'^\s+\[(\d+)\] = "(.*)",\s*$',line)
        if m: d[int(m.group(1))]=m.group(2).replace('\\"','"')
    return d
units=parse_units('pfq/db/units.lua'); zn=parse_names('pfq/db/enUS/zones.lua')
ct=json.load(open('ct.json'))
fam={7:'carrion',26:'owl',12:'tallstrider'}
def species(v):
    if v['ctype']==7: return None
    if v['family'] in fam: return fam[v['family']]
    n=v['name'].lower()
    if re.search(r'\b(macaw|cockatoo|cockatiel|parrot)\b',n): return 'parrot'
    if re.search(r'\bchicken\b',n) and 'mechanical' not in n and 'polymorph' not in n: return 'chicken'
    if re.search(r'\bhippogryph\b',n): return 'hippogryph'
    if re.search(r'\bgryphon\b',n): return 'gryphon'
out=[]
for k,v in ct.items():
    sp=species(v)
    if not sp: continue
    zl=units.get(int(k)) or []
    if not zl: continue
    zones={}
    for z in zl: zones[zn.get(z,str(z))]=zones.get(zn.get(z,str(z)),0)+1
    out.append(dict(id=int(k),name=v['name'],sp=sp,minl=v['minl'],maxl=v['maxl'],display=v['models'][0],rank=v.get('rank',0),zones=zones))
out.sort(key=lambda x:(x['sp'],x['minl'],x['name']))
for o in out: print(o['id'],o['sp'],o['name'],o['minl'],o['maxl'],o['display'],o['zones'])
json.dump(out,open('birds.json','w'))
print(len(out))
