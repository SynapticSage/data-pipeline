# README #

This is a franklab fork of the magland msdrift repository from github.

It contains all modified source code for drift tracking.

**How to use:**  
We can pull updates from the magland repo using:
```
git pull upstream master
```

Franklab-specific changes will only get pushed to Mari's github fork and this bitbucket repo.

## Outline of how drift tracking works ##

*  We typically use epoch boundaries as segment start times.  You can easily get these from the length of the .mda for each segment (assuming each epoch is recorded as a separate .mda, as it is with Trodes).  The --time_offsets input specifies the segment start times, in samples, starting from 0 and going to the start of the last epoch.  
*  The [MS4 batch pipeline](https://bitbucket.org/franklab/franklab_ms4/src/master/) includes a component called sort_on_segments, which runs the drift tracking pipeline.
*  All of the data are first bandpass filtered and whitened together, and these timeseries are saved to your tmp/mountainlab-tmp directory (and can also be saved as filt.mda and pre.mda if you so choose).
*  pyms.extract_timeseries extracts whitened timeseries files for each segment and saves them in the tmp directory.
*  ms4alg is then run to sort each segment individually. 
*  pyms.anneal_segments then compares each cluster in each segment to each cluster in every other segment, starting with neighboring segments.  Mutual nearest neighbors (based on shortest distance between the clusters) are merged/annealed.
*  Isolation scores are calculated on the final cluster labels across the whole day.  This is useful because low isolation scores tend to accurately represent which clusters should still be merged in mountainview, but weren’t automatically annealed. 

### How this is different than the magland repo: 
The updated version of p_anneal_segments.py has the following modifications:

Major:

*  Loops through all combinations of segments to compute distances between clusters and anneal nearest pairs, as opposed to annealing only over neighboring segments. This means that even if a given cluster is absent for some segments, it will be annealed over all segments for which it is present.  If a cluster is present only in one segment, it will be kept only in that segment.

Minor: 

*  Bug fixes to avoid crashes when a segment is empty of any clusters (if curation has already happened).  
*  Uses first and last 500 events of each cluster for template matching.  
*  Uses clip_size=50.  
*  Empty segments are reported to the console and skipped.  
*  Cluster numbers, time offests, and annealing progress are reported to the console.  

### modifications by M Sosa, after work from J Magland and J Chung