# For each step/pair in final nad_vectors, cos vs last-known nonzero vector of that pair (any earlier step)
import sys,glob,os,numpy as np
d,nat=sys.argv[1],int(sys.argv[2])
fs=sorted(glob.glob(d+'/*.nadv'),key=lambda f:float(os.path.basename(f)[:-5]))
last={}; bad=0
for f in fs:
    t=os.path.basename(f)[:-5]; A=np.loadtxt(f).reshape(-1,nat,3); out=[]
    for k,v in enumerate(A):
        n=np.linalg.norm(v)
        if n<1e-6: continue
        if k in last:
            lt,lv=last[k]; c=np.sum(v*lv)/n/np.linalg.norm(lv)
            flag=' BAD' if c<0 else ''; bad+=c<0
            out.append(f'pair{k}: cos={c:+.3f} (vs t={lt}){flag}')
        else: out.append(f'pair{k}: first')
        last[k]=(t,v)
    print(f't={t}: '+'; '.join(out))
print('sign inconsistencies:',bad)
