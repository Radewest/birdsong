import re,json,sys
def tuples(sql, table):
    out=[]
    for line in sql.splitlines():
        if not line.startswith(f"INSERT INTO `{table}`"): continue
        s=line[line.index('VALUES')+6:]
        i=0;n=len(s)
        while i<n:
            if s[i]=='(':
                i+=1; row=[]; cur=''; q=False
                while True:
                    c=s[i]
                    if q:
                        if c=='\\': cur+=s[i+1]; i+=2; continue
                        if c=="'": q=False; i+=1; continue
                        cur+=c; i+=1; continue
                    if c=="'": q=True; i+=1; continue
                    if c==',': row.append(cur); cur=''; i+=1; continue
                    if c==')': row.append(cur); i+=1; break
                    cur+=c; i+=1
                out.append(row)
            else: i+=1
    return out
sql=open('full.sql',encoding='utf-8',errors='ignore').read()
rows=tuples(sql,'creature_template')
print(len(rows),file=sys.stderr)
ct={int(r[0]):dict(name=r[1],sub=r[2],minl=int(r[3]),maxl=int(r[4]),models=[int(x) for x in r[5:9] if int(x)],family=int(r[11]),ctype=int(r[12]),rank=int(r[33])) for r in rows}
json.dump(ct,open('ct.json','w'))
