import os
import sys

parent_path=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append('/opt/mountainlab/packages/pyms')

from pyms.mlpy import ProcessorManager

import p_add_curation_tags
import p_merge_burst_parents

PM=ProcessorManager()

PM.registerProcessor(p_add_curation_tags.add_curation_tags)
PM.registerProcessor(p_merge_burst_parents.merge_burst_parents)

if not PM.run(sys.argv):
    #exit(-1)
	pass
