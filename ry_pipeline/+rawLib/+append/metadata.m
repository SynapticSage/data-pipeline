function metadata(dayDir, animID, day, varargin)

ip = inputParser;
ip.addParameter('folderGlob', '*.mda');
ip.addParameter('epochfilt', []);
ip.addParameter('dataname', 'deepinsight');
ip.addParameter('resample', []);
ip.addParameter('downsample', []);
ip.addParameter('transpose', false);
ip.addParameter('addArea', true); % Requires tetinfo
ip.addParameter('areaPythonList', true); % Because this structure being used in python
ip.parse(varargin{:})
Opt = ip.Results;

dataDir  = ndbFile.animdir(animID);

currdir = pwd;
cleanup = onCleanup(@() cd(currdir));
cd(dayDir);
epochTimes = getEpochs(1);

mdafolders = dir(Opt.folderGlob);
if ~isempty(mdafolders)
    cd(mdafolders.name)
else
    error("No mda folder")
end

mdafiles = dir('*.mda');
tetrodes = [];
channels = [];
timestampFile = contains({mdafiles.name}, 'timestamp');
timestamps = single(readmda( mdafiles(timestampFile).name ));
start = 1; % Tracks the write location of M.data matrix and tetrodes and channels vectors
for file = progress(mdafiles(:)', 'Title', 'Collecting metadata')
    if contains(file.name,'timestamps')
        continue
    end
    mdadim = readmdadims(file.name);
    channels(start:start+mdadim(1)-1) = 1:mdadim(1);
    tmp = string(split(file.name,'.'));
    nt = char(tmp(2));
    nt = str2double(nt(3:end));
    tetrodes(start:start+mdadim(1)-1) = nt;
    start = start + mdadim(1);
end

if ~isempty(Opt.resample)
    time = resample(timestamps, opt.resample);
elseif ~isempty(Opt.downsample)
    time = resample(time, Opt.downsample);
else
    time = timestamps;
end
time = time/30e3;
if ischar(Opt.epochfilt) || isstring(Opt.epochfilt)
    task = ndb.load(animID, 'task');
    Opt.epochfilt = evaluatefilter(task, Opt.epochfilt);
    Opt.epochfilt = Opt.epochfilt(Opt.epochfilt(:,1) == day, :);
    Opt.epochfilt = Opt.epochfilt(:,2);
end

for epoch = progress(1:size(epochTimes,1),'Title','Adding metadata')
    if ~isempty(Opt.epochfilt)
        if ~ismember(epoch,Opt.epochfilt)
            continue
        end
    end
    if numel(day) == 2
        if epoch ~= day(2)
            continue
        end
    end
    resultFile = sprintf('%s/RAW/%s%s%02d-%02d.mat', dataDir, animID, Opt.dataname, day(1), epoch);
    M = matfile(resultFile, 'Writable', true);
    if Opt.transpose == false
        M.tetrodes = tetrodes;
        M.channels = channels;
    else
        M.tetrodes = tetrodes';
        M.channels = channels';
    end
    if Opt.addArea
        rawLib.mod.assignarea(animID, [day, epoch], Opt);
    end
    eInds = find(time >= epochTimes(epoch,1) & time < epochTimes(epoch,2));
    if isempty(eInds)
        keyboard
    end
    eTarget = eInds - min(eInds) + 1;
    M.times = [];
    if Opt.transpose == false
        M.times(eTarget,1) = single(time(eInds))';
        M.times = single(M.times);
    else
        M.times(1,eTarget) = single(time(eInds));
        M.times = single(M.times);
    end
    
    % Ensure that time dimension matches!
    timesSize = size(M,'times');
    datSize = size(M,'data');
    if Opt.transpose == false
        assert(timesSize(1) == datSize(1));
    else
        assert(timesSize(2) == datSize(2));
    end
end
