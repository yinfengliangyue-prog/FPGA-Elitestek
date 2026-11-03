"""Independent frame-domain display model, not camera/board measurements."""
import numpy as np


def directional_support(mask,axis):
    mask=np.asarray(mask,dtype=bool)
    h,w=mask.shape
    # Each qualifying path must extend to both sides along the SAME axis.
    if axis==1:
        negative=np.logical_or.reduce([mask[k:k+h-2,:-2] for k in range(3)])
        positive=np.logical_or.reduce([mask[k:k+h-2,2:] for k in range(3)])
    else:
        negative=np.logical_or.reduce([mask[:-2,k:k+w-2] for k in range(3)])
        positive=np.logical_or.reduce([mask[2:,k:k+w-2] for k in range(3)])
    result=np.zeros_like(mask)
    result[1:-1,1:-1]=mask[1:-1,1:-1]&negative&positive
    return result


def line_render(strength,details=False):
    s=np.asarray(strength,dtype=np.int32)
    strong=s>=16
    coherent=directional_support(directional_support(strong,0),0)|directional_support(directional_support(strong,1),1)
    baseline=np.where(s>0,np.floor(64+191*np.sqrt(np.maximum(0,s-1)/254)+0.5),0).astype(np.int32)
    rendered=np.where(s<16,s*4,np.where(coherent,192+s//4,baseline)).astype('uint8')
    assert np.array_equal(rendered>0,s>0)
    assert np.all(rendered[s<16]<=baseline[s<16])
    assert np.all(rendered[(s>=16)&~coherent]==baseline[(s>=16)&~coherent])
    if details:return rendered,coherent,baseline.astype('uint8')
    return rendered
