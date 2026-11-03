"""Independent BAL frame model; CLEAN uses the preserved46 reference."""
import numpy as np
from line_render46_reference import line_render as clean_render,directional_support


def line_render(strength,details=False):
    s=np.asarray(strength,dtype=np.int32)
    clean,_,baseline=clean_render(s,True)
    vertical=s>=5;horizontal=vertical.copy()
    for _ in range(4):
        vertical=directional_support(vertical,0)
        horizontal=directional_support(horizontal,1)
    restored=(vertical|horizontal)&(s<16)
    balanced=np.where(restored,112+3*s,clean).astype('uint8')
    assert np.array_equal(balanced>0,s>0)
    assert np.array_equal(balanced[s<5],clean[s<5])
    assert np.array_equal(balanced[s>=16],clean[s>=16])
    if details:return balanced,restored,clean,baseline
    return balanced
