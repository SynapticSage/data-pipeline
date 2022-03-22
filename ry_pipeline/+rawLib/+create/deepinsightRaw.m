function deepinsightRaw(dayDir, animID, day, varargin)
% Genrates a matrix of all channel wise information per epoch 
%
% creates a file with fields
% +-- .data  (T x M)
% |
% +-- .channels (1 x M)
% |
% +-- .times (T x 1)
% |
% +-- .area (1 x M)
ip = inputParser;
ip.addParameter('epochfilt', []);
ip.addParameter('folderGlob', '*.mda');
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
progBar = ProgressBar(numel(mdafiles),'Title','mda files');
for file = mdafiles'
    if contains(file.name,'timestamps')
        continue
    end
    progBar.printMessage("Reading mda")
    A = int16(readmda(file.name));
    progBar.printMessage("Done!")
    if ~isempty(Opt.resample)
        [A, time] = resample(A, timestamps, opt.resample);
    elseif ~isempty(Opt.downsample)
        A    = resample(time, Opt.downsample);
        time = resample(time, Opt.downsample);
    else
       time = timestamps;
    end
    time = time/30000;
    progBarEpoch = ProgressBar(size(epochTimes,1),'Title','epoch partition');
    for epoch = 1:size(epochTimes,1)
        e = epoch;
        if ~isempty(Opt.epochfilt)
            if ~ismember(e,Opt.epochfilt)
                continue
            end
        end
        eInds = find(time >= epochTimes(e,1) & time < epochTimes(e,2));
        if numel(day) == 1
            resultFile = sprintf('%s/RAW/%s%s%02d-%02d.mat', dataDir, animID, Opt.dataname, day, epoch);
            progBarEpoch.printMessage("Day " + day + " Epoch " + e);
        elseif numel(day) == 2
            if epoch ~= day(2)
                continue
            else
                resultFile = sprintf('%s/RAW/%s%s%02d-%02d.mat', dataDir, animID, Opt.dataname, day(1), epoch);
                progBarEpoch.printMessage("Day " + day(1) + " Epoch " + e);
            end
        else
            error("Day must be day or [day epoch]")
        end
        M = matfile(resultFile, 'Writable', true);
        eTarget = eInds - min(eInds) + 1;
        progBarEpoch.printMessage("..writing epoch..");
        if Opt.transpose == true
            M.data(start:start+size(A,1)-1, eTarget) = A(:, eInds); % In matlab, this will make time on axis 2, but in python on first axi
        elseif Opt.transpose == false
            M.data(eTarget, start:start+size(A,1)-1) = A(:, eInds)'; % In matlab, this will make time on axis 2, but in python on first axi
        end
        progBarEpoch.printMessage("..done..")
        clear M
        progBarEpoch.step([],[],[]);
    end
    progBarEpoch.release()
    clear progBarEpoch
    progBar.printMessage(newline())
    progBar.printMessage("Finished mda file")
    channels(start:start+size(A,1)-1) = 1:size(A,1);
    tmp = string(split(file.name,'.'));
    nt = char(tmp(2));
    nt = str2double(nt(3:end));
    tetrodes(start:start+size(A,1)-1) = nt;
    start = start + size(A,1);
    progBar.step([],[],[]);
end

% Add metadata
rawLib.append.metadata(dayDir, animID, day, Opt);
