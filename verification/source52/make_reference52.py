"""Independent frame-domain Canny/49 BAL and RGB887 transport reference."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
from canny_reference import canny
from line_render_reference import line_render
V=Path(__file__).parent
hd='--hd' in sys.argv
w,h,n=(1920,1080,16) if hd else (64,64,230)
out=V/('reference_fullhd.hex' if hd else 'reference_small.hex')
def frame(f):
 y,x=np.mgrid[:h,:w]
 neutral=((x//2)%4==0)&(y%4==0)
 r=np.full((h,w),f,dtype=np.uint32)
 g=np.where(neutral,f,0).astype(np.uint32)
 b=np.where(neutral,f,(y*7+x)%128).astype(np.uint32)
 # Every estimator sample is gray; all others have G=0 and cannot qualify.
 assert np.all(r[::4,::8]==g[::4,::8]) and np.all(g[::4,::8]==b[::4,::8])
 c=canny(np.stack([r,g,b],-1),high=6,low=3,noise=0,impulse=True)
 strength=np.where(c['edge']!=0,c['nms'],0).astype(np.uint8)
 balanced=line_render(strength).astype(np.uint32)
 bal=balanced.reshape(h//2,2,w//2,2).max(axis=(1,3))
 red=(c['edge'].reshape(h//2,2,w//2,2).max(axis=(1,3))!=0).astype(np.uint32)
 return (bal<<24)|(red<<23)|(r[::2,::2]<<15)|(g[::2,::2]<<7)|(b[::2,::2]>>1)
signature=hashlib.sha256(b''.join((V/name).read_bytes() for name in ['make_reference52.py','canny_reference.py','line_render_reference.py','line_render46_reference.py'])).hexdigest()
meta=out.with_suffix('.json')
if not(out.exists() and meta.exists() and json.loads(meta.read_text()).get('generator_sha256')==signature):
 with out.open('wb') as fp:
  for f in range(1,n+1):np.savetxt(fp,frame(f).ravel(),fmt='%08x')
 meta.write_text(json.dumps(dict(frames=n,width=w,height=h,format='BAL8 RED1 RGB887',generator_sha256=signature,sha256=hashlib.sha256(out.read_bytes()).hexdigest()),indent=2))
print('PASS independent Canny/BAL/RGB887 reference',w,h,n,flush=True)
