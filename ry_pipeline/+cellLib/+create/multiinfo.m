    function multiinfo(animdirect, fileprefix, append)
% Multiunit cluster info -- sort of for uncurated spikes info ... useful when working with
% initial cluster guess data
%
% This function created a cellinfo file in the animal's data directory.
% For each cell, the spikewidth, mean rate, and number of spikes is saved.  If a cellinfo file
% exists and new data is being added, set APPEND to 1.
%
% MCZ ADD- If day unclustered, make NaNs

if animdirect(end) ~= filesep
    animdirect = [animdirect filesep];
end

multiinfo = [];
if (nargin < 3)
    append = 0;
end
if append
    try
        load([animdirect, fileprefix,'multiinfo']);
    end
end
tetinfo = ndb.load(fileprefix, "tetinfo");
spikefiles = dir([animdirect, fileprefix, 'multiunit*']);
for i = progress(1:length(spikefiles),'Title', 'Iterating multiunit files')
    load([animdirect, spikefiles(i).name]);
    spikes = multiunit;
    timerange = cellfetch(spikes, 'timerange');
    for j = 1:size(timerange.index,1)

        d = timerange.index(j,1);
        e = timerange.index(j,2);
        t = timerange.index(j,3);
        c = timerange.index(j,4);
        if ndb.exist(tetinfo, [d e t])
            tet = ndb.get(tetinfo, [d,e,t]);
        else
            tet = struct();
        end

        multiinfo{d}{e}{t}{c}.spikewidth = timerange.values{j};

        try
            spikewidth = spikes{d}{e}{t}{c}.spikewidth;
        catch
            spikewidth = NaN;
        end

        try

            [csi propbursts] = computecsi(...
                spikes{d}{e}{t}{c}.data(:,1), ...
                spikes{d}{e}{t}{c}.data(:,6), 10);

        catch

            csi        = NaN;
            propbursts = NaN;

        end

        try

            epochtime = diff(spikes{d}{e}{t}{c}.timerange);
            numspikes = size(spikes{d}{e}{t}{c}.data,1);
            %d, e, t, c
            tag = spikes{d}{e}{t}{c}.tag;
            multiinfo{d}{e}{t}{c}.meanrate   = numspikes/epochtime;
            multiinfo{d}{e}{t}{c}.numspikes  = numspikes;
            multiinfo{d}{e}{t}{c}.spikewidth = spikewidth;
            multiinfo{d}{e}{t}{c}.csi        = csi;
            multiinfo{d}{e}{t}{c}.propbursts = propbursts;
            multiinfo{d}{e}{t}{c}.tag = tag;
            metrics = spikes{d}{e}{t}{c}.metrics;
            for metric = string(fieldnames(metrics))'
                multiinfo{d}{e}{t}{c}.(metric)  = metrics.(metric);
            end
            multiinfo{d}{e}{t}{c}.msID  = spikes{d}{e}{t}{c}.msID;
            if ~isempty(tet)
                for field = string(fieldnames(tet))'
                    cellinfo{d}{e}{t}{c}.(metric)  = tet.(field);
                end
            end

        catch

            tag = spikes{d}{e}{t}{c}.tag;
            multiinfo{d}{e}{t}{c}.meanrate   = NaN;
            multiinfo{d}{e}{t}{c}.numspikes  = NaN;
            multiinfo{d}{e}{t}{c}.spikewidth = NaN;
            multiinfo{d}{e}{t}{c}.csi        = NaN;
            multiinfo{d}{e}{t}{c}.propbursts = NaN;
            multiinfo{d}{e}{t}{c}.tag = tag;

        end
    end
end

save([animdirect,fileprefix,'multiinfo'],'multiinfo');
