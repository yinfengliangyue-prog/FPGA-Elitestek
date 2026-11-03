"""Independent NumPy Sobel and 2x2 reduction, for faster full-HD scoreboards."""
from pathlib import Path
import argparse,hashlib,json
import numpy as np

def frame(w,h,f):
    y,x=np.mgrid[:h,:w]
    g=(x*3+y*5)%32+np.where(x>=w//4+f%(w//4),48,0)
    b=(y*7+x)%128
    gray=(77*f+150*g+29*b)>>8
    gx=gray[:-2,2:]+2*gray[1:-1,2:]+gray[2:,2:]-gray[:-2,:-2]-2*gray[1:-1,:-2]-gray[2:,:-2]
    gy=gray[2:,:-2]+2*gray[2:,1:-1]+gray[2:,2:]-gray[:-2,:-2]-2*gray[:-2,1:-1]-gray[:-2,2:]
    mag=np.zeros((h,w),dtype=np.uint32)
    mag[1:-1,1:-1]=np.minimum(255,(np.abs(gx)+np.abs(gy))>>3)
    reduced=mag.reshape(h//2,2,w//2,2).max(axis=(1,3))
    return (reduced<<24)|np.uint32(f<<16)|(g[::2,::2].astype(np.uint32)<<8)|b[::2,::2].astype(np.uint32)

def self_test():
    for f in [1,7,12]:
        got=frame(64,64,f)
        def gray(x,y):
            g=(x*3+y*5)%32+(48 if x>=16+f%16 else 0)
            b=(y*7+x)%128
            return (77*f+150*g+29*b)>>8
        def mag(x,y):
            if x in (0,63) or y in (0,63):return 0
            gx=gray(x+1,y-1)+2*gray(x+1,y)+gray(x+1,y+1)-gray(x-1,y-1)-2*gray(x-1,y)-gray(x-1,y+1)
            gy=gray(x-1,y+1)+2*gray(x,y+1)+gray(x+1,y+1)-gray(x-1,y-1)-2*gray(x,y-1)-gray(x+1,y-1)
            return min(255,(abs(gx)+abs(gy))>>3)
        for yy in range(32):
            for xx in range(32):
                x,y=2*xx,2*yy
                m=max(mag(x,y),mag(x+1,y),mag(x,y+1),mag(x+1,y+1))
                g=(x*3+y*5)%32+(48 if x>=16+f%16 else 0)
                b=(y*7+x)%128
                assert int(got[yy,xx])==(m<<24)|(f<<16)|(g<<8)|b
    print('PASS NUMPY23 scalar cross-check: 3072 reduced pixels')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--frames',type=int,default=16);args=ap.parse_args()
    self_test()
    out=Path(__file__).parent/'reference_fullhd.hex'
    with out.open('wb') as fp:
        for f in range(1,args.frames+1):np.savetxt(fp,frame(1920,1080,f).ravel(),fmt='%08x')
    meta={'frames':args.frames,'width':1920,'height':1080,'thumbnail':[960,540],
          'format':'row-major {max_2x2_mag8,RGB888_upper_left}',
          'sha256':hashlib.sha256(out.read_bytes()).hexdigest()}
    out.with_suffix('.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
    print('Reference generated:',out)
