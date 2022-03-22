
%METADATA
%% Libaries!
addpath(genpath('~/Code/pipeline'))
addpath(genpath('~/Code/pipeline/TrodesToMatlab'))
addpath(genpath('~/Code/pipeline/SpikeGadgets'))
addpath(genpath('~/Code/pipeline/pipeline-filterframework'))
addpath(genpath('~/Code/pipeline/TrodesExtractionGUI'))
addpath(genpath('~/Code/pipeline/preprocess'))
addpath(genpath('~/Code/pipeline/ry_pipeline'))
addpath(genpath('~/Code/Src_Matlab/ry_Utility'))


% have usrlocal, Src_matlab, matclust, TrodesToMatlab, and Pipeline in path

%% FOLDER metadata
% General FS
root = fullfile(filesep, 'media','ryoung','Thalamus');
expDir = fullfile(root, 'ry_GoalCoding_Project');

% Animal specific files
animalRawDir    = '/Volumes/FastData/Raw/ry_GoalCoding_Project/RY16_experiment/RY16_fix'
animalRawDirOut = '/Volumes/FastData/Raw/ry_GoalCoding_Project/RY16_experiment/RY16_fix'
%animalRawDir    = '/Volumes/GenuDrive/RY16_fix'
%animalRawDirOut = '/Volumes/GenuDrive/RY16_fix'
[dayDirs, sessionList] = ry_selectDays('/Volumes/Cerebellum/RY9/', 55, 68)

% Define file prefixes, used to fix filenames in a day_dir and for creating
% #FIX_FILENAMES
prefixes = ["RY16_"] + string(sessionList)' + "_expDay9 + compose("%02d",sessionList-min(sessionList)+1)';
prefixes = cellstr(prefixes(:));
           
configFiles = repmat({'~/Configs/RY9/RY9.trodesconf'}, ...
                      numel(dayDirs), 1);

recOrder = ry_generateRecOrder(animalRawDir, dayDirs,...
    'exclusions', [],...
    'skipNonexist', true)

 
%% ECU Metadata
dioPulsePerChannel = [];
 
%% Behavior metadata
% RL = cell(1,numel(dayDirs));

%% Start log file

% If logFile, attach a header sequence
if exist(logFile,'file')
    HEADER = 1;
else
    HEADER = 0;
end

% Get our diary up and running
diary(logFile)
if HEADER
    fprintf('\n\n')
end
disp(datestr(now,0))
fprintf('Preprocessing %s\nExperiment Directory: %s\nRaw Directory: %s\nData Directory: %s\n\n',animID,expDir,animDir,dataDir);
disp('Day Order:')
disp(dayDirs')
fprintf('\n\n')

preprocess = ["dio"]
        
%% DAY DEPENDENT  (pos, lfp, spikes, dio, task, linpos)
numDays = numel(ry_selectDays(animDir));
for sessionNum = 1:numDays
    
    fprintf('PreProcessing %s Day %02i...\n',animID,sessionNum);
    dayDir = fullfile(animDir, dayDirs{sessionNum});

    % POSITION
    if contains(prepocess, "pos")
        % TO DO: add mcz_posinterp vargin to mcz_createNQPosFiles
        %mcz_createNQPosFiles(rawDir, dataDir, animID, sessionNum)
        %rn_createNQPosFiles(dayDir,dataDir,animID,sessionNum,[],'diodenum',1)
        %rn_createNQRawPosFiles(dataDir,animID,sessionNum,[]);
        %rn_createNQPosFiles(dayDirs{sessionNum},dataDir,animID,sessionNum,[])
        %mcz_createNQPosFiles(rawDir, dataDir, animID, sessionNum, dioFramePulseChannelName)
    end
    
    % LFP
    if contains(preprocess, "lfp")
        rn_createNQLFPFiles(dayDir, dataDir, animID, sessionNum);
    end

    % SPIKES
    if contains(preprocess, "spikes")
        %mcz_createNQSpikesFiles(rawDir, dataDir, animID, sessionNum) 
    end

    % DIO
    if contains(preprocess, "dio")
        %mcz_createNQDIOFiles(dayDir, dataDir, animID, sessionNum
        mcz_createNQDIOFilesFromStateScriptLogs(dayDirs{sessionNum}, dataDir, animID, sessionNum)
    end

    % TASK
    if contains(prepocess, "task")
        %createtaskstruct(dataDir,animID,[sessionNum 2; sessionNum 4], 'getcoord_wtrack');
        %sj_updatetaskstruct(dataDir,animID,sessionNum,[1 3 5], 'sleep');
        %sj_updatetaskenv(dataDir,animID,sessionNum,[2 4], 'wtr1');   
        %sj_lineardayprocess(dataDir,animID,sessionNum,'welldist',15)            
    end

end

%% DAY INDEPENDENT (cellinfo, tetinfo)
disp('Creating cell & tet info structures')

% Initialize marker structures
createtetinfostruct(dataDir,animID);
mcz_createcellinfostruct(dataDir,animID); 

% Describe tetrodes
sj_addtetrodelocation(dataDir,    animID, tetLists{hpc}, 'CA1');
sj_addtetrodelocation(dataDir,    animID, tetLists{pfc}, 'PFC');
sj_addtetrodelocation(dataDir,    animID, tetLists{ctx}, 'Ctx');
sj_addtetrodedescription(dataDir, animID, refList{hpc},  'CA1Ref');
sj_addtetrodedescription(dataDir, animID, refList{pfc},  'PFCRef');
sj_addtetrodedescription(dataDir, animID, refList{ctx},  'CtxRef');
%sj_addtetrodedescription(dir1,prefix,riptetlist,'riptet'); 
%sj_addcellinfotag2(dataDir,animID); 

%% EEG preprocess
% Get number of epochs
cd(dayDir)
epochs = getEpochs(1);
nEpochs = size(epochs,1);

% Reference EEG or rename?
configurationUnreferenced = ry_getConfigRefState('configDir', '~/Configs/RY9/');
cd(currDir)
if any(configurationUnreferenced)
    % refData -- an E x N matrix with the local reference for each tetrode
    %            where unused tetrodes have a ref of zero.
    refData = zeros(nEpochs,nTets);
    for i=1:numel(tetLists),
        refData(:,tetLists{i}) = refList{sessionNum}(i);
    end
         
    mcz_createRefEEG(rawDir, dataDir, animID, sessionNum, refData)
else
    ry_renameEEGtoEEGref()
end
filterDir = [fileparts(which('mcz_deltadayprocess.m')) filesep 'Filters' filesep];
fprintf('Delta Filtering LFPs...\n')
mcz_deltadayprocess(dayDir,  dataDir, animID, sessionNum, 'f', [filterDir 'deltafilter.mat'])
fprintf('Gamma Filtering LFPs...\n')
mcz_gammadayprocess(dayDir,  dataDir, animID, sessionNum, 'f', [filterDir 'gammafilter.mat'])
fprintf('Ripple Filtering LFPs...\n')
mcz_rippledayprocess(dayDir, dataDir, animID, sessionNum, 'f', [filterDir 'ripplefilter.mat'])
fprintf('Theta Filtering LFPs...\n')
mcz_thetadayprocess(dayDir,  dataDir, animID, sessionNum, 'f', [filterDir 'thetafilter.mat'])
 
%% Goalmaze Specific
%% -----------------
% Matlab files sometimes have gui objects that make them unloadable: delete those
matfileDirectory =  fullfile(animDir, 'matlab')
matfileLib.sanitizeDirectory(matfileDirectory)
% Create callback data struct
callbackLib.preprocessCallback('RY9', ...
    'mapping', dayList, ..
    'searchdirectory', matfileDirectory)
