function cells(animal, varargin)
% createcellinfostruct(animal,fileprefix)
% createcellinfostruct(animal,fileprefix,append)
%
% This function created a cellinfo file in the animal's data directory.
% For each cell, the spikewidth, mean rate, and number of spikes is saved.  If a cellinfo file
% exists and new data is being added, set APPEND to 1.
%
% MCZ ADD- If day unclustered, make NaNs
%
%
% Ryan - modernized to ndb framework, enhanced append capability (more
% intelligent), added mountainsort metrics, added tetinfo to cells

ip = inputParser;
ip.addParameter('index',[]); % if not given, performs this for all spikes files found
ip.addParameter('append',true,@islogical) % if not given, performs this for all spikes files found
ip.parse(varargin{:});
Opt = ip.Results;

cellinfo = [];
if Opt.append && ndbFile.exist(animal, 'cellinfo')
    cellinfo = ndb.load(animal,  'cellinfo');
end
tetinfo = ndb.load(animal, "tetinfo");
spikefiles = ndbFile.files([animal,"spikes"], Opt.index);
for i = progress(1:length(spikefiles),'Title', 'Iterating spikes files')
    load(fullfile(spikefiles(i).folder, spikefiles(i).name));
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
        cellinfo{d}{e}{t}{c}.spikewidth = timerange.values{j};
        try
            spikewidth = spikes{d}{e}{t}{c}.spikewidth;
        catch
            spikewidth = NaN;
        end
        try
            [csi, propbursts] = computecsi(spikes{d}{e}{t}{c}.data(:, 1), ...
                spikes{d}{e}{t}{c}.data(:,6), 10);
        catch
            csi = NaN;
            propbursts = NaN;
        end

        try

            epochtime = diff(spikes{d}{e}{t}{c}.timerange);
            numspikes = size(spikes{d}{e}{t}{c}.data,1);

            %d, e, t, c
            tag = spikes{d}{e}{t}{c}.tag;
            cellinfo{d}{e}{t}{c}.meanrate   = numspikes/epochtime;
            cellinfo{d}{e}{t}{c}.numspikes  = numspikes;
            cellinfo{d}{e}{t}{c}.spikewidth = spikewidth;
            cellinfo{d}{e}{t}{c}.csi        = csi;
            cellinfo{d}{e}{t}{c}.propbursts = propbursts;
            cellinfo{d}{e}{t}{c}.tag        = tag;
            metrics = spikes{d}{e}{t}{c}.metrics;
            for metric = string(fieldnames(metrics))'
                cellinfo{d}{e}{t}{c}.(metric)  = metrics.(metric);
            end
            cellinfo{d}{e}{t}{c}.msID  = spikes{d}{e}{t}{c}.msID;
            if ~isempty(tet)
                for field = string(fieldnames(tet))'
                    cellinfo{d}{e}{t}{c}.(field)  = tet.(field);
                end
            end

        catch ME

            disp(ME)

            tag = spikes{d}{e}{t}{c}.tag;
            cellinfo{d}{e}{t}{c}.meanrate   = NaN;
            cellinfo{d}{e}{t}{c}.numspikes  = NaN;
            cellinfo{d}{e}{t}{c}.spikewidth = NaN;
            cellinfo{d}{e}{t}{c}.csi        = NaN;
            cellinfo{d}{e}{t}{c}.propbursts = NaN;
            cellinfo{d}{e}{t}{c}.tag = tag;

        end
    end
end

ndb.save(cellinfo, animal, "cellinfo", 0)
