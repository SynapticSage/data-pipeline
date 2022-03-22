# README #

### This repo provides a processor for tagged curation of sort results
The original curation strategy for Mountainsort involves setting rejecting clusters that do not meet criteria, based on thresholds set for cluster metrics such as isolation score, noise overlap, SNR. 
These clusters were marked with the tag "rejected" and would NOT be exported as part of the curated_firings.mda output. 
This strategy becomes problematic when the merging of accepted clusters then requires the recalculation of cluster metrics, a process which should be done in relation to ALL detected clusters, not just accepted ones. 
This processor allows curation with a system of tags such that ALL clusters are saved, but those that don't meet criteria are tagged as "mua", rather than "rejected" which then allows them to be saved rather than discarded in the export curated firings step.

Additionally, this package differs from the orginal curation process by splitting out the merging of burst parent clusters to an independent processor.  This allows the user to choose whether or not to include this step in curation.


### To register these processors:

Put this package (or a link to this package) in `~/.mountainlab/packages/`
(Create this directory if it don't exist; this is where mountainsort will look for additional packages.)

The tagged_curation.py and the tagged_curation.mp scripts should be found automatically and will register the listed processors with mountainsort. Confirm this by running `mp-list-processors`, and look for the lines:
~~~
pyms.add_curation_tags
pyms.merge_burst_parents
~~~
	
### written by AK Gillespie, based on work from J Magland and J Chung