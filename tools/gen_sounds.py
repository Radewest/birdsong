import re,sys,collections
rows={}
for line in open(sys.argv[1],encoding='utf-8',errors='ignore'):
    i,_,p=line.strip().partition(';')
    if p.endswith('.ogg'): rows[p]=int(i)
folders=['owl','carrion','tallstrider','parrot','chicken','seagull','gryphon','hippogryph','raven','stormcrow','turkey','tickbird']
cats=[('call',r'preaggro|stand|rearup|clickable'),('alarm',r'aggro'),('attack',r'attack'),('wound',r'wound'),('death',r'death')]
out=collections.OrderedDict()
for f in folders:
    d=collections.OrderedDict((c,[]) for c,_ in cats)
    for p,i in sorted(rows.items(),key=lambda x:x[1]):
        if p.startswith(f'sound/creature/{f}/'):
            n=p.rsplit('/',1)[1]
            for c,rx in cats:
                if re.search(rx,n): d[c].append(i); break
    out[f]=d
out['owl']['call']=[rows[f'sound/doodad/fx_owl0{k}.ogg'] for k in range(1,6)]+out['owl']['call']
lua=['-- Birdsong: sound IDs (FileDataIDs) generated from the community listfile (github.com/wowdev/wow-listfile).','-- Regenerate with tools/gen_sounds.py. Categories: call, alarm, attack, wound, death.','local _, ns = ...','ns.SOUNDS = {']
for f,d in out.items():
    parts=[f'{c} = {{{", ".join(map(str,v))}}}' for c,v in d.items() if v]
    lua.append(f'  {f} = {{ {", ".join(parts)} }},')
lua.append('}')
amb=['forestnormal','westfall','grasslands','jungle','plainsdesert','wetlands','marsh','beach','foresthigh','forestsnow','enchantedforest','forestdarkenchanted','forestscary','plaguelands','canyondesert','saltflats','volcanic','deadwindpass']
lua.append('ns.AMBIENCE_IDS = {')
for a in amb:
    vals=[]
    for tod in ('day','night'):
        cands=[f'sound/ambience/zoneambience/{a}{tod}.ogg']
        if a=='enchantedforest' and tod=='day': cands.append('sound/ambience/zoneambience/enchangedforestday.ogg')
        idv=next((rows[c] for c in cands if c in rows),None)
        vals.append(f'{tod} = {idv}' if idv else None)
    lua.append(f'  {a} = {{ {", ".join(v for v in vals if v)} }},')
lua.append('}')
print('\n'.join(lua))
