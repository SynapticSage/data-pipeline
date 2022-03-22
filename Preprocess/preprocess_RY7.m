%% PATHS
addpath(genpath('~/Code/pipeline'))
addpath(genpath('~/Code/projects/goalmazebehavior'))


%% FOLDER 
% General FS
root = fullfile(filesep, 'media','ryoung','Thalamus');
expDir = fullfile(root, 'ry_GoalCoding_Project');

% Animal specific files
animID = 'RY7';
rawDir = [expDir filesep [animID '_experiment'] filesep animID filesep];

% Day directories
% NOTE : You can start the first day on 64 if you process it with deeplabcut! it's not right now
[dayDirs, sessionList, dayIndex] = ry_selectDays(rawDir, 65);

% Where to put the data and log files
currDir = pwd;
dataDir = [expDir filesep [animID '_experiment'] filesep animID '_direct' filesep];
logFile = [dataDir animID 'preprocess.log'];


%% metadata: TETRODE
[hpc, pfc, ctx] = deal(1, 2, 3);
areas =    {'hpc',...
            'pfc',...
            'ctx'};
tetLists = {[10, 12], ... HPC  (11 is reference according to my config file ... need to check this!)
            [13], ... CTX
            [1, 2, 3]}; % PFC 14 and 15 would also be options
refList =  {11, ... HPC ref
            11, ... CTX ref
            16}; %  PFC ref
nTets = max(cellfun(@max, tetLists));
%riptetlist = [1,2,3,4,5,6]; % Where to grab ripples from?
 
%% metadata: ECU
dioPulsePerChannel = [];
 
%% metadata: Behavior
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
fprintf('Preprocessing %s\nExperiment Directory: %s\nRaw Directory: %s\nData Directory: %s\n\n',animID,expDir,rawDir,dataDir);
disp('Day Order:')
disp(dayDirs')
fprintf('\n\n')

preprocess = ["pos"]
        
%% DAY DEPENDENT  (pos, lfp, spikes, dio, task, linpos)
numDays = numel(dayDirs);
dayStart = 1; %find(contains(dayDirs,'64_'));
dayStop  = numDays; %find(contains(dayDirs,'64_'));
for sessionNum = dayStart:dayStop
    
    fprintf('PreProcessing %s Day %02i...\n',animID,sessionNum);
    dayDir = fullfile(rawDir, dayDirs{sessionNum});

    % POSITION
    if contains(preprocess, "pos")
        %======== DeepLabCut FILES ========================
        dlcDir= fullfile(expDir, 'deeplabcut', ...
                                'goalmaze_implant-Ryan-and-Ziyi-2019-08-31');
        ry_deeplabcut.generateRawPosFile(dlcDir, dayDir, dataDir,  animID, sessionNum)
                                          %'cmPerPixel', );
        %deeplabcutLib.generateDeepinsightPos(dlcDirectory, 'RY7', sessionList);
                                           %'cmPerPixel', );
        %ry_createNQPosFiles(dayDir, dataDir, animID, sessionNum);
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
    if contains(preprocess, "task")
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
configurationUnreferenced = ~ry_getConfigRefState('configDir', sprintf('~/Configs/%s/',animID));
cd(currDir)
if any(configurationUnreferenced)
    % refData -- an E x N matrix with the local reference for each tetrode
    %            where unused tetrodes have a ref of zero.
    refData = zeros(nEpochs,nTets);
    for i=1:numel(tetLists),
        refData(:,tetLists{i}) = refList{sessionNum}(i);
    end
         
    mcz_createRefEEG(rawDir, dataDir, animID, sessionNum, refData)
    filterDir = [fileparts(which('mcz_deltadayprocess.m')) filesep 'Filters' filesep];
    fprintf('Delta Filtering LFPs...\n')
    mcz_deltadayprocess(dayDir,  dataDir, animID, sessionNum, 'f', [filterDir 'deltafilter.mat'])
    fprintf('Gamma Filtering LFPs...\n')
    mcz_gammadayprocess(dayDir,  dataDir, animID, sessionNum, 'f', [filterDir 'gammafilter.mat'])
    fprintf('Ripple Filtering LFPs...\n')
    mcz_rippledayprocess(dayDir, dataDir, animID, sessionNum, 'f', [filterDir 'ripplefilter.mat'])
    fprintf('Theta Filtering LFPs...\n')
    mcz_thetadayprocess(dayDir,  dataDir, animID, sessionNum, 'f', [filterDir 'thetafilter.mat'])
else
    ry_renameEEGtoEEGref()
end
 
%% Goalmaze Specific
%% -----------------
%======== CALLBACK FILES ==========================
% Matlab files sometimes have gui objects that make them unloadable: delete those
matfileDirectory =  fullfile(rawDir, 'matlab');
matfileLib.sanitizeDirectory(matfileDirectory)
% Create callback data struct
callbackLib.generateCallbackFiles(animID, sessionList, ...
    'mapping', dayIndex, ...
    'searchdirectory', matfileDirectory)
% Generate maze files from callback files
% (these store the meanings of the DIOs for the given experiment)
callbackLib.generateMazeFiles(animID);


%======== TrialFiles FILES ========================
trialLib.trialsFromDio(animID, dayIndex);

%% Pre-analysis
%======== Higher order trial information ========
%======== Higher order cell information =========
