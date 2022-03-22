import numpy as np
import json
import sys, os

parent_path=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.append('/opt/mountainlab/packages/pyms')


processor_name='pyms.add_curation_tags'
processor_version='0.11'

def add_curation_tags(*, metrics, metrics_tagged, firing_rate_thresh=0, isolation_thresh=0, noise_overlap_thresh=1, peak_snr_thresh=0, mv2file=[]):
    
    """
    Add tags to the metrics file to reflect which clusters should be rejected based on curation criteria
    Based on create/apply label map by J Chung and J Magland
    
    Parameters
    ----------
    metrics : INPUT
        Path of metrics json file to add tags 
    metrics_tagged : OUTPUT
        Path of metricsjson which has been updated with cluster tags
        ...

    firing_rate_thresh : float64
        (Optional) firing rate must be above this
    isolation_thresh : float64
        (Optional) isolation must be above this
    noise_overlap_thresh : float64
        (Optional) noise_overlap_thresh must be below this
    peak_snr_thresh : float64
        (Optional) peak snr must be above this
    mv2file : string
        (Optional) if tags have already been added, update new metrics file with them
        ...
    """
    #Load json
    with open(metrics) as metrics_json:
        metrics_data = json.load(metrics_json)

    if mv2file:
        with open(mv2file) as f:
            mv2 = json.load(f)

    #Iterate through all clusters
    for idx in range(len(metrics_data['clusters'])):

        # initialize empty tags key
        if 'tags' not in metrics_data['clusters'][idx]:
            metrics_data['clusters'][idx]['tags'] = []

        #if the mv2 was passed in, use those tags
        if mv2file:
            clustlabel = metrics_data['clusters'][idx]['label']
            metrics_data['clusters'][idx]['tags'] = mv2['cluster_attributes'][str(clustlabel)]['tags']

        if metrics_data['clusters'][idx]['metrics']['firing_rate'] < firing_rate_thresh or \
            metrics_data['clusters'][idx]['metrics']['isolation'] < isolation_thresh or \
            metrics_data['clusters'][idx]['metrics']['noise_overlap'] > noise_overlap_thresh or \
            metrics_data['clusters'][idx]['metrics']['peak_snr'] < peak_snr_thresh:

            #Add "rejected" tag to cluster metrics (if it isnt already there)
            if 'mua' not in metrics_data['clusters'][idx]['tags']:
                metrics_data['clusters'][idx]['tags'] += ['mua'] 
            #if the cluster was formerly tagged as accepted, remove that   
            if 'accepted' in metrics_data['clusters'][idx]['tags']:
                metrics_data['clusters'][idx]['tags'].remove('accepted')

    #Write out updated metrics json
    with open(metrics_tagged,'w') as f:
        json.dump(metrics_data, f, sort_keys=True, indent=4)

add_curation_tags.name = processor_name
add_curation_tags.version = processor_version
add_curation_tags.author = 'AKGillespie'
