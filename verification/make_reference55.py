from pathlib import Path
import sys,json,hashlib
import numpy as np
V=Path(__file__).parent;sys.path.insert(0,str(V/'source52'))
from canny_reference import canny
from line_render_reference import line_render
hd='--hd' in sys.argv;w,h,n=(1920,1080,16) if hd else (64,64,230)
lut=np.array([int(255*(min(q,510)/510)**(1/2.2)+.5) for q in range(512)],dtype=np.int32)
def wb53(rgb):
 p=rgb[...,::-1].astype(np.int32)
 c=lut[np.clip((p*np.array([320,158,329])+64)//128,0,511)]
 lum=(c@np.array([77,150,29])+128)>>8
 a=np.pad(lum,((0,0),(1,1)),mode='edge');hh=(a[:,:-2]+2*a[:,1:-1]+a[:,2:]+2)>>2
 a=np.pad(hh,((1,1),(0,0)),mode='edge');blur=(a[:-2]+2*a[1:-1]+a[2:]+2)>>2
 delta=(np.clip(lum-blur,-16,16)*4+8)>>4
 return np.clip(c+delta[...,None],0,255)
def frame(f):
 y,x=np.mgrid[:h,:w];neutral=((x//2)%4==0)&(y%4==0)
 r=np.full((h,w),f,dtype=np.uint32);g=np.where(neutral,f,0).astype(np.uint32);b=np.where(neutral,f,(y*7+x)%128).astype(np.uint32)
 rgb=np.stack([r,g,b],-1);c=canny(rgb,high=6,low=3,noise=0,impulse=True)
 strength=np.where(c['edge']!=0,c['nms'],0).astype(np.uint8)
 bal,_,clean,_=line_render(strength,True)
 bal=bal.reshape(h//2,2,w//2,2).max((1,3)).astype(np.uint32);clean=clean.reshape(h//2,2,w//2,2).max((1,3)).astype(np.uint32)
 edge=(c['edge'].reshape(h//2,2,w//2,2).max((1,3))!=0).astype(np.uint32)
 p=wb53(rgb)[::2,::2].astype(np.uint32)
 return (bal<<24)|(clean<<16)|(edge<<15)|((p[...,0]>>3)<<9)|((p[...,1]>>3)<<4)|(p[...,2]>>4)
out=V/('reference55_hd.hex' if hd else 'reference55_small.hex');meta=out.with_suffix('.json')
sig=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
if not(out.exists() and meta.exists() and json.loads(meta.read_text()).get('generator_sha256')==sig):
 with out.open('wb') as fp:
  for f in range(1,n+1):np.savetxt(fp,frame(f).ravel(),fmt='%08x')
 meta.write_text(json.dumps(dict(frames=n,width=w,height=h,generator_sha256=sig,sha256=hashlib.sha256(out.read_bytes()).hexdigest()),indent=2))
print('PASS independent WB53 baseline + Canny/BAL/CLEAN reference',w,h,n,flush=True)
