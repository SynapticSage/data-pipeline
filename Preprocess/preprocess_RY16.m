        
% ----------------
% Preprocess steps
% ----------------
dospiking     = false;
dolfp         = true;
dobehavior    = true;
dobarriers    = false;
dodecode      = false;
dorsync       = true;
doprocessmaze = false;

% ---------------
% Main parameters
% ---------------
animal = 'RY16';
%dayStart = 27; % Day to being analyzing
%dayStop  = 17; % Day to end analyzing
dayStart = 36; % Day to being analyzing
dayStop = 36; % Day to being analyzing
if dayStop < dayStart
    direction = -1; % Direction to iterate days -1:highest_to_lowest, +1 lowest_to_highest
else
    direction = 1; % Direction to iterate days -1:highest_to_lowest, +1 lowest_to_highest
end


%% ========================
%% PATHS, FOLDERS, METADATA
%% ========================
% ----
% PATH
% ----
addpath(genpath('~/Code/pipeline'))
addpath(genpath('~/Code/projects/goalmazebehavior'))
addpath(genpath('/Volumes/MATLAB-Drive/linearized'))
addpath('~/Code')

Info = animalinfo(animal);

% -------
% FOLDER 
% -------
expDir = fullfile(root);
% ---------------------
% Animal specific files
% ---------------------
rawDir = Info.rawDir;
[dayDirs, sessionList, sessionIndex] = ry_selectDays(Info.rawDir, 34);

dataDir       = Info.directDir;
spikesDataDir = Info.directDir;

% -----------
% Config file
% -----------
configFile =  sprintf('~/Configs/%s/%s_fix.trodesconf', animal, animal);

% --------
% Log file
% --------
currDir = pwd;
logFile = [dataDir animal 'preprocess.log'];

% Tetrode metadata
% ----------------
[hpcL, hpcR, pfc] = deal(1, 2, 3);
[tetStruct, areas, tetList, refList] = ry_getAreasTetsRefs('configFile', configFile,...
    'removeAreas', [ "SuperDead" ],...
    'selectMostFrequentRef', true);
refList(hpcL) = refList(hpcR);
nTets = max(cellfun(@max, tetList));
%riptetlist = [1,2,3,4,5,6]; % Where to grab ripples from?

%% Start log file
%% ==============
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
fprintf('Preprocessing %s\nExperiment Directory: %s\nRaw Directory: %s\nData Directory: %s\n\n',animal,Info.expDir,Info.rawDir,Info.directDir);
disp('Day Order:')
disp(dayDirs')
fprintf('\n\n')

%% ====================================================
%% DAY DEPENDENT  (POS, LFP, SPIKES, DIO, TASK)
%% ====================================================
numDays  = max(sessionIndex);
sessionAverages = 29:36; % whether to get cm per pix and maze coords from session averages, [] means no
if direction == -1
    daySequence = dayStart:-1:dayStop;
    day = dayStop; % put this here in case running from console.
else
    daySequence = dayStart:1:dayStop;
    day = dayStart; % put this here in case running from console.
end

%% ===================================================
%% GOALMAZE SPECIFIC (requires animaldef at this point
%% ===================================================
if doprocessmaze
    matfileDirectory =  fullfile(expDir, 'matlab');
    % Matlab files sometimes have gui objects that make them unloadable: delete those
    matfileLib.sanitizeDirectory(matfileDirectory);
    % Create callback data struct
    callbackLib.preprocess(dataDir, matfileDirectory, animal, dayDirs(dayStart:direction:dayStop),...
        'mapping', sessionIndex(dayStart:direction:dayStop))
    % Generate maze files from callback files
    % (these store the meanings of the DIOs for the given experiment)
    callbackLib.generateMazeFiles(animal, dataDir, ...
        "orderingFields", ["platforms","zones"],...
        "nameRemapping",  ["leds","cue"; ...
                           "leds_negative", "cue_negative";...
                           "rewards", "reward";...
                           "normal", "arena";...
                           "inputs", "poke"],...
        'regionLabels', ["home","arena"]);
    %PROBABLY_SAME = 1;
    %dioLib.generateDioTables(animal, 'assumeMazeFilesSame', PROBABLY_SAME);
end

%% -------------------------------------------
%% Copy deepLabCut outputs to animal folders
%% -------------------------------------------
% In this future, this might be better left as an extraction step
copy_dlc_files = false; % false when you've already run this once
if copy_dlc_files
    dlcDir    = {};
    dlcDir{1} = fullfile(expDir, 'deeplabcut', 'goalmaze_led-Ryan-2020-05-25');
    dlcDir{2} = fullfile(expDir, 'deeplabcut', 'goalmaze_tape-Ryan-2020-05-28');
    ry_deeplabcut.copyDLCResultsToRawDir(dlcDir, rawDir+dayDirs);
end

if dorsync
    % Configure Citadel rsync push/pull process
    rsync_kws = {'local', 'archer', 'remote', 'citadel','test',false,...
                'mountainsort', true, 'clearMountainsort', true,...
                'add_pull_excludes', [],...
                'ext_exclusions', ["h264", "raw", "rec", "raw.mda", "rawmda", "raw.LFP"]};
    if ~dospiking
        rsync_kws{12} = [rsync_kws{12}, "spikes", "mda"];
    end
    if ~dolfp
        rsync_kws{12} = [rsync_kws{12}, "lfp"];
    end
    if ~dodecode
        rsync_kws{12} = [rsync_kws{12}, "raw"];
    end
    % We need to make sure any rawdata on the server that's about to be
    % processed is available here.
    util.rsync.rawpull(animal, dayDirs{daySequence(1)}, 'day', dayStart, rsync_kws{:});
end

day = dayStart;
for day = daySequence

    fprintf('PreProcessing %s Day %02i...\n',animal,day);
    dayDir = fullfile(rawDir, dayDirs{day}); 

    % ---------
    % Checksum 
    % ---------
    [validation, validationTable] = ry_validateAndFixFolder(dayDir);
    if ~validation % checks if folder has one *.stateScriptLog per epoch and if each trodesComment for each epoch only one start and one stop
        disp(validationTable)
    end

    % ---------------------
    % Local field potential
    % ---------------------
    % RAW dependencies --> exportRAW
    %rawLib.ry_createNQRawLFPFiles(dayDir, dataDir, animal, day);
    %rawLib.ry_createNQRawFiles(dayDir, dataDir, animal, day);
    % LFP dependencies --> exportLFP
    if dolfp && (numel(dir(fullfile(dayDir, '*.LFP','*')))-2) > 0
        rn_createNQLFPFiles(dayDir, dataDir, animal, day);
    end

    % --------
    % Behavior
    % --------
    if dobehavior
        % POSITION  -> dependcies: deeplabcut
        % ------------------------
        if ~exist('cmperpix','var')
            cmperpix  = ry_deeplabcut.cmperpix(dayDir, dataDir, animal, day, 'CM', 'useAverageOfSessions', sessionAverages);
        end
        ry_deeplabcut.createNQRawPosFiles(dayDir, dataDir,  animal, day,...
        'tableOutputDir', fullfile(dataDir,'deepinsight'),...
        'cmPerPixel', cmperpix);
        ry_deeplabcut.createNQPosFiles(dayDir, dataDir, animal, day);
        

        % TASK FILE GENERATION dependencies --> POS, curated trodesComments
        % -----------------------------------------------------------------
        taskLib.initializeTaskStruct(dayDir, dataDir, animal, day, 'videoToDataDir', 'link');
        taskLib.addCoordinateLabels(dayDir, dataDir, animal, day,...
                                    'coordprogram', @getcoord_gmaze,...
                                    'tryAverageOfSessions', sessionAverages,...
                                    'overwrite',  false);
        taskSheet = fullfile(expDir, 'ry16.xlsx');
        taskLib.taskPropFromExcelSheet(dayDir, animal, taskSheet, day,...
            'dayFromDayDir', true);

        % DIO dependencies -> exportDIO or .stateScriptLog
        % ------------------------------------------------
        ECU_MCU_misalign = true;
        if ECU_MCU_misalign
            ry_createNQDIOFilesFromStateScriptLogs(dayDir, dataDir, animal, day)
            %ry_deeplabcut.createDIOalignFromDLC(dayDir, dataDir,  animal, day, ...
            %                                    'applyCorrection', true, ...
            %                                    'tableOutputDir', fullfile(dataDir,'diofix'))
            dioLib.create.diotable(animal, day);                             
            register.offsetDio(animal, day, 'interactive', false)
        else
            mcz_createNQDIOFiles(dayDir, dataDir, animal, day)
        end

        %======== Higher order trial information ========
        % Trials dependencies -> Task (w/ coords), Pos, DIO, Dio-video registration
        trialLib.create.events(animal, day);
        trialLib.create.traj(animal,   day);
        posLib.create.goalPos(animal,  day);
    end

    % --------------------
    % Barriers and objects
    % --------------------
    if dobarriers
    end
   
    % ----------------------
    % Spiking (Mountainsort)
    % ----------------------
    if dospiking
        mdaFolder_regExp = '(?<anim>[A-Z]+[0-9]+)_(?<overallDay>[0-9]{1,3})_expDay(?<day>[0-9]{1,2})_?(?<date>[0-9]{6,8})?_?(?<epoch>[0-9]*)(?<epoch_name>\w*).mda';
        tet_options = ry_ml_tetoption(unique(areas), tetList);
        ml_process_animal(animal, rawDir,...
            'dataDir',       spikesDataDir,    ...
            'dayDirs',       dayDir,           ...
            'days',   day,       ...
            'daysToProcess', day,       ...
            'pat',           mdaFolder_regExp, ...
            'extractmarks',  true,             ...
            'tet_options', tet_options);

        readSpikes =  fullfile(spikesDataDir, 'MountainSort',...
            sprintf('%s_%02d.mountain',animal,day));
        convert_ml_to_FF_withMultiunitAndMarks(animal, readSpikes, ...
            day, 'overwrite', true, ...
            'keyboard_on_notag', false);
        util.notify.pushover("Spikes", "Finished spikess/marks");

        % 
        tetrode.update.tetinfo(animal,  day);
        cellLib.create.cellinfo(dataDir, animal); 
        cellLib.create.multiinfo(dataDir, animal); 
        util.notify.pushover("Spikes", "Finished creating info structs");

        % Describe tetrodes
        % -----------------
        tetrode.add(animal, day, "hemisphere",...
            [tetList{hpcR},  tetList{pfc}, refList{hpcR}], 'right',...
            [tetList{hpcL}, refList{hpcL}], 'left');
        tetrode.add(animal, day, "area",...
            [tetList{hpcR} tetList{hpcL}, refList{hpcR}, refList{hpcL}], 'CA1',...
            tetList{pfc}, 'PFC');
        tetrode.add(animal, day, "descrip",...
            [refList{hpcR} refList{hpcL}],  'CA1Ref',...
             refList{pfc},  'PFCRef');
        util.notify.pushover("Spikes", "Finished markgin tetrode props");

        % If you plan to use tables immediately, run these!
        % -------------------------------------------------
        addpath('~/Code/analysis/')
        coding.table.info(animal, 'cellinfo', 'inds', day);
        coding.table.info(animal, 'multiinfo', 'inds', day);
        coding.table.info(animal, 'tetinfo', 'inds', day);
        util.notify.pushover("Spikes", "Finished tables");

    end

    % ---------------------------------- 
    % DEEPINSIGHT : (Spikes +  LFP data)
    % ---------------------------------- 
    % Dependencies : requieres tetrode information 
    if dodecode
        rawLib.create.deepinsightRaw(dayDir, animal, day, 'transpose', true);
        rawLib.append.behavior(animal, day,...
            'egocentric', [],...
            'tasktype', 'run',...
            'changefield', {'time','postime'},...
            'transpose', true);
        rawLib.append.marks(animal, day)

    end

    if dolfp
        eegFiles    = ndbFile.exist(animal, 'eeg', day);
        eegRefFiles = ndbFile.exist(animal, 'eegref', day);
        if eegFiles
            fprintf('Ripple Filtering LFPs...\n')
            mcz_rippledayprocess(dayDir, dataDir, animal, day, 'f', [filterDir 'ripplefilter.mat'])
            fprintf('Theta Filtering LFPs...\n')
            mcz_thetadayprocess(dayDir,  dataDir, animal, day, 'f', [filterDir 'thetafilter.mat'])
        elseif eegRefFiles
            fprintf('Theta Filtering LFPs...\n')
            mcz_thetadayprocess(dayDir,  dataDir, animal, day, 'f', [filterDir 'thetafilter.mat'], 'ref', 1)
            fprintf('Delta Filtering LFPs...\n')
            mcz_deltadayprocess(dayDir,  dataDir, animal, day, 'f', [filterDir 'deltafilter.mat'], 'ref', 1)
        end
        if eegRefFiles
            fprintf('Ripple Filtering LFPs...\n')
            mcz_rippledayprocess(dayDir, dataDir, animal, day, 'f', [filterDir 'ripplefilter.mat'])
            rippletype = 'rippleref';
        elseif eegFiles
            fprintf('Ripple Filtering LFPs...\n')
            mcz_rippledayprocess(dayDir, dataDir, animal, day, 'f', [filterDir 'ripplefilter.mat'], 'ref', 0)
            rippletype = 'ripple';
        end
        % generating ripple events
        min_suprathresh_duration = 0.015;
        nstd = 2;
        lfpLib.create.generateSPWRevents(dataDir, animal, day, cat(2,tetList{1:3}), ...
            min_suprathresh_duration, nstd,...
            'rippletype', rippletype)
        lfpLib.create.generateGlobalRipples('RY16');
        % and cortical ripples
        lfpLib.create.generateGlobalRipples('RY16', 'brainarea', 'PFC', 'name', 'rippletimepfc');
    end
    
    % -----------------------
    % Rsync results to server
    % -----------------------
    % Most essential for large/huge 256 channel datasets ... remove the current folder working on and
    % pull the next folder from the server.
    if dorsync
        util.rsync.rawpush(animal, dayDirs{day}, rsync_kws{:}, 'deleteExpensiveFolders', ["mda", "rawmda","LFP","raw.LFP","raw"]); % pushes changes
        util.rsync.rawpush(animal, dayDirs{day+direction}, rsync_kws{:}); % pushes any updates in the next folder beforre pulling
        util.rsync.rawpull(animal, dayDirs{day+direction}, 'day', day+direction, rsync_kws{:}); % pull the next day of data
    end

end
keyboard

%% ===================================
%% DAY INDEPENDENT (cellinfo, tetinfo)
%% ===================================
disp('Creating/updating cell & tet info structures')

% ----------------------------
% Clean metadata structures 
% ----------------------------
tetrode.update.tetinfo(dataDir,  animal);
cellLib.create.cellinfo(dataDir, animal); 
cellLib.create.multiinfo(dataDir, animal); 
coding.make.info_table(animal, 'cellinfo');
coding.make.info_table(animal, 'tetinfo');

% -------------------
% LFP post-processing
% -------------------
% Get number of epochs
cd(dayDir)
epochs = getEpochs(1);
nEpochs = size(epochs,1);

% ------------------------
% Reference EEG or rename?
% ------------------------

% Reference?
% ----------
eegFiles = ndbFile.exist(animal, 'eeg');
configurationUnreferenced = ~ry_getRefState('animal',animal, 'inds', day, 'lfp', true); % when true, it searches all of the lfp files for the current day, when false, it searches the config file
cd(currDir)
filterDir = [fullfile(fileparts(which('mcz_deltadayprocess.m')), 'Filters') filesep];
if eegFiles && configurationUnreferenced
    if any(configurationUnreferenced)
        % refData -- an E x N matrix with the local reference for each tetrode
        %            where unused tetrodes have a ref of zero.
        refData = zeros(nEpochs,nTets);
        for i=1:numel(tetList)
            refData(:,tetList{i}) = refList{day}(i);
        end
             
        mcz_createRefEEG(rawDir, dataDir, animal, day, refData)
else ~configurationUnreferenced % eeg files and they say "referenced"
    % ALREADY referenced, but we're called them EEG....
    % So we need to rename EEG -> EEGREF
    lfpLib.ref.rename_eeg2eegref(animal, day);
end
