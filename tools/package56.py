# Legacy command alias; current FINAL06 packaging.
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('package06.py')),run_name='__main__')
