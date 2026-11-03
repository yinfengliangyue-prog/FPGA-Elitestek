from pathlib import Path
import sys,json,hashlib
import numpy as np
P=Path(__file__).resolve().parents[1];V=P/'verification'
sys.path[:0]=[str(V/'source52'),str(P/'tools')]
from canny_reference import canny
from noise_reference import projected_boxes,sampling_box,normalize

# readmemh values are hexadecimal, not decimal.
image=np.array([int(x,16) for x in (V/'number/expression_hd_images.mem').read_text().split()],dtype=np.uint8).reshape(1080,1920)
# Separate clean-background input: the original244/252 checker texture is a
# deliberate Sobel noise fixture and is retained unchanged for the legacy test.
image=np.where(image>200,252,image).astype(np.uint8)
np.savetxt(V/'expr_canny06_images.mem',image.ravel(),fmt='%02x')
crop=image[140:940,544:1376]
c=canny(np.repeat(crop[...,None],3,axis=2),high=10,low=5,noise=0,impulse=True)
edge=c['edge'];grid=((edge[16:784,32:800]!=0).reshape(192,4,192,4).sum((1,3))>=2)
boxes=projected_boxes(grid);assert len(boxes)==5,boxes
expected=np.concatenate([normalize(grid,sampling_box(boxes,i,192)).ravel() for i in range(5)])
for name,values in [('expr_canny06_edges.mem',edge.ravel()),('expr_canny06_expected.mem',expected),('expr_canny06_boxes.mem',np.array(boxes).ravel())]:
    np.savetxt(V/name,values,fmt='%02x')
(V/'EXPR_CANNY_REFERENCE.json').write_text(json.dumps(dict(high=10,low=5,noise=True,width=832,height=800,roi=768,grid=192,cell_min_hits=2,scene='Existing12+34 glyphs on clean252 background; original checker244/252 remains the separate legacy Sobel fixture',boxes=boxes,edge_pixels=int((edge!=0).sum()),generator_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),dependencies={str(f.relative_to(P)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [V/'source52/canny_reference.py',P/'tools/noise_reference.py',V/'number/expression_hd_images.mem']},outputs={n:hashlib.sha256((V/n).read_bytes()).hexdigest() for n in ['expr_canny06_images.mem','expr_canny06_edges.mem','expr_canny06_expected.mem','expr_canny06_boxes.mem']}),indent=2),encoding='utf-8')
if True:
    print('Generated independent Canny and occupancy2/16 normalization fixtures',boxes)
    sys.exit(0)
