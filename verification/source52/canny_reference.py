"""Independent integer frame model: bounded hardware and exact BFS hysteresis.
No claim of cv2.Canny bit equivalence: explicit 3x3 kernel, L1/8, NMS tie policy.
"""
from collections import deque
import numpy as np

def neighbors(a):
    h,w=a.shape
    return [a[dy:dy+h-2,dx:dx+w-2] for dy in range(3) for dx in range(3)]

def propagate(candidate, strong, passes=None):
    candidate=np.asarray(candidate,dtype=bool).copy()
    candidate[[0,-1],:]=False;candidate[:,[0,-1]]=False
    accepted=np.asarray(strong,dtype=bool)&candidate
    if passes is None:
        todo=deque(map(tuple,np.argwhere(accepted)))
        while todo:
            y,x=todo.popleft()
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    yy,xx=y+dy,x+dx
                    if 0<=yy<candidate.shape[0] and 0<=xx<candidate.shape[1] and candidate[yy,xx] and not accepted[yy,xx]:
                        accepted[yy,xx]=True;todo.append((yy,xx))
    else:
        for _ in range(passes):
            next_=np.zeros_like(accepted)
            next_[1:-1,1:-1]=np.logical_or.reduce(neighbors(accepted))
            accepted=candidate&next_
    return accepted

def impulse_filter(gray):
    gray=np.asarray(gray,dtype=np.int32)
    patches=np.lib.stride_tricks.sliding_window_view(gray,(3,3)).reshape(gray.shape[0]-2,gray.shape[1]-2,9)
    ring=patches[:,:,[0,1,2,3,5,6,7,8]]
    lo=ring.min(-1);hi=ring.max(-1);center=gray[1:-1,1:-1]
    result=gray.copy()
    result[1:-1,1:-1]=np.where(center>hi+12,hi,np.where(center+12<lo,lo,center))
    return result

def canny(rgb, high=6, passes=2, low=2, exposure=0, noise=3, impulse=True):
    if not 0<=high<=255:raise ValueError('high must be 0..255')
    p=np.asarray(rgb,dtype=np.int32)
    gray=(77*p[...,0]+150*p[...,1]+29*p[...,2])>>8
    if impulse:
        gray=impulse_filter(gray)
    smooth=gray.copy()
    a,b,c,d,e,f,g,h,i=neighbors(gray)
    smooth[1:-1,1:-1]=(a+2*b+c+2*d+4*e+2*f+g+2*h+i+8)>>4
    a,b,c,d,e,f,g,h,i=neighbors(smooth)
    gx=c+2*f+i-a-2*d-g;gy=g+2*h+i-a-2*b-c
    ax,ay=np.abs(gx),np.abs(gy)
    mag=np.zeros_like(gray);direction=np.zeros_like(gray)
    mag[1:-1,1:-1]=np.minimum(255,(np.maximum(0,ax+ay-(0 if exposure==0 else noise*(2 if exposure==2 else 1)))<<exposure)>>1)
    direction[1:-1,1:-1]=np.where(ay*256<=ax*106,0,np.where(ax*256<=ay*106,2,np.where((gx<0)==(gy<0),1,3)))
    a,b,c,d,e,f,g,h,i=neighbors(mag);z=direction[1:-1,1:-1]
    neg=np.select([z==0,z==1,z==2],[d,a,b],default=c)
    pos=np.select([z==0,z==1,z==2],[f,i,h],default=g)
    nms=np.zeros_like(gray)
    nms[1:-1,1:-1]=np.where((e>0)&(e>neg)&(e>=pos),e,0)
    hi=max(1,high);lo=max(1,min(hi,low))
    candidate=(nms>=lo)&(nms>0);strong=(nms>=hi)&(nms>0)
    accepted=propagate(candidate,strong,passes)
    return dict(gray=gray.astype('uint8'),smooth=smooth.astype('uint8'),mag=mag.astype('uint8'),
                direction=direction.astype('uint8'),nms=nms.astype('uint8'),candidate=candidate,
                strong=strong,edge=accepted.astype('uint8')*255)

if __name__=='__main__':
    import argparse
    from pathlib import Path
    from PIL import Image
    ap=argparse.ArgumentParser();ap.add_argument('input');ap.add_argument('output')
    ap.add_argument('--high',type=int,default=16);ap.add_argument('--passes',type=int,default=2)
    ap.add_argument('--exact',action='store_true');args=ap.parse_args()
    rgb=np.array(Image.open(args.input).convert('RGB'))
    Image.fromarray(canny(rgb,args.high,None if args.exact else args.passes)['edge']).save(args.output)
