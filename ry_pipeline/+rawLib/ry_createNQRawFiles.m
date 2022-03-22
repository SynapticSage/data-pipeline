function ry_createNQRawFiles(rawDir, dataDir, animID, sessionNum)
%createNQLFPFiles(rawDir, dataDir,animID,sessionNum)
%
%RN EDIT 8/3/17: CHANGE FROM mcz_createNQLFPFiles: fix to work with LFP data from different versions of Trodes. Some LFP dat files have ntrode_channel_1based instead of ntrode_channel
%
%This function extracts LFP information and saves data in the FF format.
%It is assumed that there is
%one (and only one) folder named '*.LFP' in the current working
%directory that contains binary files for each LFP channel (result of extractLFPBinaryFiles.m)
%
%The function also assumes that there is a '*.time' folder in the current directory
%conaining time information about the session (from
%extractTimeBinaryFile.m).
%
%
%rawDir -- the directory where the raw dat folders are located
%dataDir -- the directory where the processed files should be saved
%animID -- a string identifying the animal's id (appended to the
%beginning of the files).
%sessionNum -- the session number (in chronological order for the animal)
% Raw broad spectrum files (Spike + LFP band)
disp('Processing RAWs...')

currDir = pwd;
cd(rawDir);
cleanup=onCleanup(@() cd(currDir));

improperlyTitled = dir('*.raw.LFP');
keyboard
for file = improperlyTitled'
    rawname = replace(file.name,'.raw.LFP', '.raw');
    eval(['!rawold=' rawname]);
    !rm -rf $(pwd)/$rawname
    eval(['!rawnew=' file.name]);
    !mv $(pwd)/$rawold $(pwd)/$rawnew
end

filesInDir = dir('*.raw');
if ~isempty(filesInDir)
    filesInDir = filesInDir([filesInDir.isdir]);
end
if ~isempty(filesInDir) && numel(filesInDir)==1
    targetFolder = filesInDir.name;
else
    targetFolder = [];
    if numel(filesInDir) == 0
        error('Raw folder not found in this directory.');
    else
        error('You have too many raw folders in this directory.');
    end
end

epochList = getEpochs(1);  %assumes that there is at least a 1-second gap in data between epochs

cd(targetFolder);
datFiles = dir('*.raw_*.dat');

if (isempty(datFiles))
    cd(currDir);
    error('No RAW binary files found in RAW folder.');
end

timeDatFiles = dir('*.timestamps.dat');

if (isempty(datFiles))
    cd(currDir);
    error('No timestamps file found in raw folder.');
end
timeData = readTrodesExtractedDataFile(timeDatFiles(1).name);
timeData = double(timeData.fields(1).data) / timeData.clockrate;
if ~exist([dataDir filesep 'RAW' filesep],'dir')
    mkdir([dataDir filesep 'RAW' filesep])
end
for datFileInd = 1:length(datFiles)
    disp(datFiles(datFileInd).name);
    try
        data = readTrodesExtractedDataFile(datFiles(datFileInd).name);
    catch
        warning('Skipping %s: not readable', datFiles(datFileInd).name);
        %keyboard
        continue
    end
    rawData =  double(data.fields(1).data);
    if  numel(rawData) ~= numel(timeData)
        warning('Skipping %s: timestamps do not match raw', datFiles(datFileInd).name);
        keyboard
        continue
    end

    nTrodeNum = data.ntrode_id;
    if isfield(data,'ntrode_channel')
        channelNum = data.ntrode_channel;
    elseif isfield(data,'ntrode_channel_1based')
        channelNum = data.ntrode_channel_1based;
    else
        channelNum = 0;
    end

    for e = 1:size(epochList,1)
        currentSession = sessionNum;
        currentTimeRange = epochList(e,:);
        rawFile = sprintf('%sRAW%s%sraw%02i-%02i-%02i-%02i.mat',[dataDir filesep],filesep,animID,sessionNum,e,nTrodeNum,channelNum);
        if exist(rawFile,'file')
            fprintf('Raw already processed for %02i-%02i-%02i-%02i, continuing...\n',sessionNum,e,nTrodeNum,channelNum);
            continue;
        end
        raw = []; % mcz from Binary2FF_LFP.m
        epochDataInd = find((timeData >= currentTimeRange(1))&(timeData < currentTimeRange(2)));

        raw{currentSession}{e}{nTrodeNum}.descript = data.description; % mcz from Binary2FF_LFP.m
        raw{currentSession}{e}{nTrodeNum}.timerange = [timeData(epochDataInd(1)) timeData(epochDataInd(end))];
        %redundant notation
        raw{currentSession}{e}{nTrodeNum}.clockrate = data.clockrate;  % mcz from Binary2FF_LFP.m
        raw{currentSession}{e}{nTrodeNum}.starttime = timeData(epochDataInd(1));
        raw{currentSession}{e}{nTrodeNum}.endtime = timeData(epochDataInd(end));
        raw{currentSession}{e}{nTrodeNum}.samprate = data.clockrate/data.decimation;
        raw{currentSession}{e}{nTrodeNum}.nTrode = nTrodeNum;
        raw{currentSession}{e}{nTrodeNum}.nTrodeChannel = channelNum;
        raw{currentSession}{e}{nTrodeNum}.data = rawData(epochDataInd,1) * data.voltage_scaling *-1;
        raw{currentSession}{e}{nTrodeNum}.data_voltage_scaled = 1;  % mcz from Binary2FF_LFP.m
        raw{currentSession}{e}{nTrodeNum}.data_voltage_inverted = 1;

        if strcmp(data.reference, 'on');                      % mcz from Binary2FF_LFP.m
            raw{currentSession}{e}{nTrodeNum}.referenced = 1; % mcz from Binary2FF_LFP.m
        else                                                  % mcz from Binary2FF_LFP.m
            raw{currentSession}{e}{nTrodeNum}.referenced = 0; % mcz from Binary2FF_LFP.m
        end                                                   % mcz from Binary2FF_LFP.m

        raw{currentSession}{e}{nTrodeNum}.voltage_scaling = data.voltage_scaling; % mcz from Binary2FF_LFP.m

        save(rawFile,'-v6','raw');
    end
end
cd(currDir);
