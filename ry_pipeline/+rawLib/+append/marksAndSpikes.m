function marksAndSpikes(animal, dayepoch, varargin)
% Add marks the the raw decoding structure

ip = inputParser;
ip.addParameter('folderGlob', '*.mda');
ip.addParameter('taskfilt', 'string($type)=="run"');
ip.addParameter('dataname', 'deepinsight');
ip.addParameter('addAcceptedSpikes', 'spikes'); % if not empty, we lookup and append the data in this struture
ip.addParameter('addMuaSpikes', 'multiunit'); % same
ip.addParameter('addMarks', true); % same
ip.addParameter('resample', []);
ip.addParameter('downsample', []);
ip.addParameter('transpose', false);
ip.KeepUnmatched= true;
ip.parse(varargin{:})
Opt = ip.Results;
Unmatched = ip.Unmatched;

keyboard

tetinfo = ndb.load(animal,'tetinfo','indices',dayepoch);
tiInds  = ndb.indicesMatrixForm(tetinfo);
rawInds = ndbFile.indicesMatrixForm(animal, 'deepinsight',...
    'indices', dayepoch);
indices =  intersect(rawInds, tiInds(:,1:2), 'rows');

if ~isempty(Opt.taskfilt) && (isstring(Opt.taskfilt) || ischar(Opt.taskfilt))
    task = ndb.load(animal, 'task');
    eInds = evaluatefilter(task, Opt.taskfilt);
    indices = intersect(indices, eInds, 'rows');
elseif ~isempty(Opt.taskfilt) && isnumeric(Opt.taskfilt)
    if isrow(Opt.taskfilt) || iscolumn(Opt.taskfilt)
        indices = indices(ismember(indices(:, end), Opt.taskfilt(:)), :);
    end
end


for ind = indices'

    day    =  ind(1);
    epoch  =  ind(2);
    if epoch == 2
        continue
    end

    resultFile = sprintf('%s/RAW/%s%s%02d-%02d.mat', ...
                         ndbFile.animdir(animal), animal, Opt.dataname, day, epoch);
    M = matfile(resultFile, 'Writable', true);

    if Opt.addMarks
        try
            marks   = units.getMarkMatrix(animal, [day epoch], ip.Unmatched);
            encodeMarks = true;
        catch
            encodeMarks = false;
        end

        if encodeMarks
            M.multiunitSpikes = marks.spikes;
            M.marks           = marks.marks;
            M.markAreas       = marks.areas;
            M.markTetrodes    = marks.tetrodePerUnit;
            M.multiunitTime   = marks.time';
        end
    end

    if ~isempty(Opt.addAcceptedSpikes)
        spikes   = units.getRateMatrix(animal, [day epoch],...
                                    'unit', Opt.addAcceptedSpikes,...
                                    'taskFilter', Opt.taskfilt);
        spikes   = units.sparseToDense(spikes);
        M.spikeCountMatrix = spikes.spikeCountMatrix';
        M.spikeCountTime = spikes.time;
        sct = spikes.time;
        M.spikeCountDt = spikes.dt;
    end
    if ~isempty(Opt.addMuaSpikes)
        spikes   = units.getRateMatrix(animal, [day epoch],...
                                    'unit', Opt.addMuaSpikes,...
                                    'taskFilter', Opt.taskfilt);
        filt = spikes.cellTable.tag == "mua";
        spikes.spikeTimes = spikes.spikeTimes(filt);
        spikes.cellTable  = spikes.cellTable(filt,:);
        spikes            = units.sparseToDense(spikes);
        M.muaCountMatrix  = spikes.spikeCountMatrix';
        try
            assert(isequal(spikes.time, sct))
        catch
            keyboard
        end
    end
    
    clear M;

end
