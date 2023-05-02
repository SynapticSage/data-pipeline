% ---------------- Preprocess steps
% ----------------
dospiking     = false;
dolfp         = false;
dobehavior    = false;
dobarriers    = false;
dodecode      = false;
domarks       = false; % if decode activate, puts marks into decode files
dorsync       = false;
doprocessmaze = false;
dospikingcuration = true;

% ----------------
% Mountainsort controls and knobs
% ----------------
extractmarks         = false; % produce marks for marked point process?
overwriteMoutainSort = false; % overwrite ms files?
% Regular expression for finding mountainsort folders (if your naming differs, you can change this)
%mdaFolder_regExp = '(?<anim>[A-Z]+[0-9]+)_(?<overallDay>[0-9]{1,3})_expDay(?<day>[0-9]{1,2})_?(?<date>[0-9]{6,8})?_?(?<epoch>[0-9]*)(?<epoch_name>\w*).mda';
mdaFolder_regExp = '(?<anim>[A-Z]+[0-9]+)_?(?<overallDay>[0-9]{1,3})?_(?<day>[0-9]{1,2})_?(?<date>[0-9]{6,8})?_?(?<epoch>[0-9]*)(?<epoch_name>\w*).mda';

% ---------------
% Main parameters
% ---------------
animal = 'RY9';
dayStart = 21; % Day to being analyzing
dayStop  = 1;  % Day to end analyzing
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
addpath(genpath('~/Code/src_matlab/ry_Utility'))

% ---------------------
% Animal specific files
% ---------------------
Info   = animalinfo(animal);
%[dayDirs, sessionList] = ry_selectDays('/Volumes/Cerebellum/RY9/', 55, 68)
[dayDirs, sessionList, sessionIndex] = ry_selectDays(Info.rawDir,...
                                                     Info.rawFirstSession);
% --------
% Log file
% --------
currDir = pwd;
logFile = [Info.directDir animal 'preprocess.log'];

% Tetrode metadata
% ----------------
[hpcL, hpcR, pfc] = deal(1, 2, 3);
[tetStruct, areas, tetList, refList] = ry_getAreasTetsRefs(...
    'configFile', Info.configFile,...
    'removeAreas', [ "SuperDead" ],...
    'selectMostFrequentRef', true);
refList(hpcL) = refList(hpcR);
nTets = max(cellfun(@max, tetList));
disp("Area counts")
disp({unique([tetStruct.area]), groupcounts([tetStruct.area]')'})
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

fprintf('Preprocessing %s\nExperiment Directory: %s\nRaw Directory: %s\nData Directory: %s\n\n',...
    animal,Info.expDir,Info.rawDir,Info.directDir);
disp('Day Order:')
disp(dayDirs')
fprintf('\n\n')

%% ====================================================
%% DAY DEPENDENT  (POS, LFP, SPIKES, DIO, TASK)
%% ====================================================
numDays  = max(sessionIndex);
sessionAverages = []; % whether to get cm per pix and maze coords from session averages, [] means no
if direction == -1
    daySequence = dayStart:-1:dayStop;
    sessionNum = dayStop; % put this here in case running from console.
else
    daySequence = dayStart:1:dayStop;
    sessionNum = dayStart; % put this here in case running from console.
end

%% ===================================================
%% GOALMAZE SPECIFIC (requires animaldef at this point
%% ===================================================
if doprocessmaze
    matfileDirectory =  fullfile(Info.expDir, 'matlab');
    % Matlab files sometimes have gui objects that make them unloadable: delete those note : pay no mind to the error messages -- they're from a complicated mathworks company gui code that I cannot silence -- nothing on
    % stackoverflow about it. the error message has no effect on the output.
    matfileLib.sanitizeDirectory(matfileDirectory);
    % Create callback data struct
    callbackLib.preprocess(Info.directDir, matfileDirectory, animal, ...
        dayDirs(dayStart:direction:dayStop),...
        'mapping', sessionIndex(dayStart:direction:dayStop))
    % Generate maze files from callback files
    % (these store the meanings of the DIOs for the given experiment)
    callbackLib.generateMazeFiles(animal, Info.directDir, ...
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
    ry_deeplabcut.copyDLCResultsToRawDir(Info.dlcDirs, Info.rawDir+dayDirs);
end

if dorsync
    % Configure Citadel rsync push/pull process
    rsync_kws = {'local', 'archer', 'remote', 'citadel','test',false,...
                'mountainsort', true, 'clearMountainsort', true,...
                'add_pull_excludes', [],...
                'ext_exclusions', ["h264", "raw", "rec",...
                                   "raw.mda", "rawmda", "raw.LFP"]};
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
    util.rsync.rawpull(animal, dayDirs{daySequence(1)}, 'sessionNum', dayStart, rsync_kws{:});
end

for sessionNum = 6:7

    day = sessionNum
    disp(dayDirs{sessionNum})
    fprintf('PreProcessing %s Day %02i...\n',animal,sessionNum);
    dayDir = fullfile(Info.rawDir, dayDirs{sessionNum}); 
    %dayDir = fullfile(Info.rawDir, "21_20211107")
    disp(dayDir)
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
    %rawLib.ry_createNQRawLFPFiles(dayDir, Info.directDir, animal, sessionNum);
    %rawLib.ry_createNQRawFiles(dayDir, Info.directDir, animal, sessionNum);
    % LFP dependencies --> exportLFP
    if dolfp && (numel(dir(fullfile(dayDir, '*.LFP','*')))-2) > 0
        rn_createNQLFPFiles(dayDir, Info.directDir, animal, sessionNum);
        % -------------------
        % LFP post-processing
        % -------------------
        % Get number of epochs
        cd(dayDir)
        epochs = getEpochs(1);
        nEpochs = size(epochs,1);

        configurationUnreferenced = ~ry_getRefState('animal',animal,'inds',day,'dataType','eeg');
        %eegrefIsRef = ry_getRefState('animal',animal,'inds',day,'dataType','eegref');
        refLabelIsCorrect = any(configurationUnreferenced);
        unrefIsActuallyRef = ~any(configurationUnreferenced);
        refFilesNotCreated = ~ndbFile.exist(animal, 'eegref', day);
        if refLabelIsCorrect && refFilesNotCreated
            % refData -- an E x N matrix with the local reference for each tetrode
            %            where unused tetrodes have a ref of zero.
            refData = zeros(nEpochs,nTets);
            for i=1:numel(tetList)
                %refData(:,tetList{i}) = refList{sessionNum}(i);
                refData(:,tetList{i}) = refList{i};
            end
            disp("Referecing")
            disp(refData)
            mcz_createRefEEG(Info.rawDir, Info.directDir, animal, sessionNum, refData)
        elseif unrefIsActuallyRef
            ry_renameEEGtoEEGref()
        end
        filterDir = [fileparts(which('thetafilter.mat')) '/'];

        % Make filtered files
        eegFiles    = ndbFile.exist(animal, 'eeg',    day);
        eegRefFiles = ndbFile.exist(animal, 'eegref', day);
        if eegFiles % low frequency defaults to unreferenced
            fprintf('Theta Filtering LFPs...\n')
            mcz_thetadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'thetafilter.mat'], 'ref', 0)
            fprintf('Delta Filtering LFPs...\n')
            mcz_deltadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'deltafilter.mat'], 'ref', 0)
        elseif eegRefFiles
            fprintf('Theta Filtering LFPs...\n')
            mcz_thetadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'thetafilter.mat'], 'ref', 1)
            fprintf('Delta Filtering LFPs...\n')
            mcz_deltadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'deltafilter.mat'], 'ref', 1)
        end
        if eegRefFiles % high frequency defaults to referenced
            fprintf('Ripple Filtering LFPs...\n')
            mcz_rippledayprocess(dayDir, Info.directDir, animal, day, 'f', [filterDir 'ripplefilter.mat'], 'ref', 1)
            rippletype = 'rippleref';
        elseif eegFiles
            fprintf('Ripple Filtering LFPs...\n')
            mcz_rippledayprocess(dayDir, Info.directDir, animal, day, 'f', [filterDir 'ripplefilter.mat'], 'ref', 0)
            rippletype = 'ripple';
        end
        % generating ripple events
        min_suprathresh_duration = 0.015;
        nstd = 2;
        lfpLib.create.generateSPWRevents(Info.directDir, animal, day, cat(2,tetList{1:3}), ...
            min_suprathresh_duration, nstd,...
            'rippletype', rippletype)
        lfpLib.create.generateGlobalRipples(animal);
        % and cortical ripples
        lfpLib.create.generateGlobalRipples(animal, 'brainarea', 'PFC', 'name', 'rippletimepfc');

    end

    % --------
    % Behavior
    % --------
    if dobehavior
        % POSITION  -> dependcies: deeplabcut
        % ------------------------
        % CMPERPIX requires rawpos first!
        ry_deeplabcut.createNQRawPosFiles(dayDir, Info.directDir,  animal, sessionNum,...
        'tableOutputDir', fullfile(Info.directDir,'deepinsight'));
        if ~exist('cmperpix','var') || isempty(cmperpix)
            cmperpix  = ry_deeplabcut.cmperpix(dayDir, Info.directDir, animal, ...
                sessionNum, 'CMB', 'useAverageOfSessions', sessionAverages)
        end
        ry_deeplabcut.createNQRawPosFiles(dayDir, Info.directDir,  animal, sessionNum,...
        'tableOutputDir', fullfile(Info.directDir,'deepinsight'),...
        'cmPerPixel', cmperpix);
        ry_deeplabcut.createNQPosFiles(dayDir, Info.directDir, animal, sessionNum);
        

        % TASK FILE GENERATION dependencies --> POS, curated trodesComments
        % -----------------------------------------------------------------
        taskLib.initializeTaskStruct(dayDir, Info.directDir, animal, sessionNum, 'videoToDataDir', 'link');
        taskLib.addCoordinateLabels(dayDir, Info.directDir, animal, sessionNum,...
                                    'coordprogram', @getcoord_gmaze,...
                                    'tryAverageOfSessions', sessionAverages,...
                                    'overwrite',  false);
        taskLib.taskPropFromNotesFiles(dayDir, animal, sessionNum);
        %taskLib.taskPropFromExcelSheet(dayDir, animal, Info.taskSheet, sessionNum, 'dayFromDayDir', true);

        % DIO dependencies -> exportDIO or .stateScriptLog
        % ------------------------------------------------
        ECU_MCU_misalign = true;
        if ECU_MCU_misalign
            ry_createNQDIOFilesFromStateScriptLogs(dayDir, Info.directDir, animal, sessionNum)
            %ry_deeplabcut.createDIOalignFromDLC(dayDir, Info.directDir,  animal, sessionNum, ...
            %                                    'applyCorrection', true, ...
            %                                    'tableOutputDir', fullfile(Info.directDir,'diofix'))
            dioLib.create.diotable(animal, sessionNum);                             
        else
            % THIS DOESN"T WORK UNLESS CONFIG FILE GIVES ALL OF THE DIOS
            mcz_createNQDIOFiles(dayDir, Info.directDir, animal, sessionNum);
            ndbFile.renameStruct(animal,"DIO","DIO","dio"); % make struct field match file name
            % this requires maze files that specify definitions of the dio
            dioLib.create.diotable(animal, sessionNum);                             
        end
        diocorrection = false;
        if diocorrection
            register.offsetDio(animal, sessionNum, 'interactive', false);
        end

        %======== Higher order trial information ========
        % Trials dependencies -> Task (w/ coords), Pos, DIO, Dio-video registration
        trialLib.create.events(animal, sessionNum);
        trialLib.create.traj(animal,   sessionNum);
        posLib.create.goalPos(animal,  sessionNum);
    end

    % --------------------
    % Barriers and objects
    % --------------------
    if dobarriers
        % Have yet to write any code for this
        % Could do brightness detection (binary) on roi lines drawn over
        % the barriers
    end
   
    % ----------------------
    % Spiking (Mountainsort)
    % ----------------------
    if dospikingcuration
        tet_options = ry_ml_tetoption(unique(areas), tetList);
        %tetsubset = cellfun(@(x) x(ismember(x,tetsubset)), tetList);
        tetsubset = []

        ml_process_animal(animal, Info.rawDir,...
            'dataDir',       Info.directDir,    ...
            'dayDirs',       dayDir,           ...
            'sessionNums',   sessionNum,       ...
            'daysToProcess', sessionNum,       ...
            'pat',           mdaFolder_regExp, ...
            'extractmarks',  extractmarks,             ...
            'overwrite', overwriteMoutainSort, ...
            'tet_list', tetsubset, ...
            'tet_options', tet_options);
        !pushover-cli "Finished clustering"

    end
    if dospiking
        ms_store = fullfile(Info.directDir, ...
                            'MountainSort',...
                             sprintf('%s_%02d.mountain',animal,sessionNum)...
                            )
        convert_ml_to_FF_withMultiunitAndMarks(animal, ms_store, ...
            sessionNum, 'tet_options', tet_options, 'overwrite', true);
        cellLib.update.cells(animal,     'index', sessionNum)
        cellLib.update.multiunit(animal, 'index', sessionNum)

        % Describe tetrodes
        % -----------------
        tetrode.add(animal, sessionNum, "hemisphere",...
            [tetList{hpcR},  tetList{pfc}, refList{hpcR}], 'right',...
            [tetList{hpcL}, refList{hpcL}], 'left');
        tetrode.add(animal, sessionNum, "area",...
            [tetList{hpcR} tetList{hpcL}, refList{hpcR}, refList{hpcL}], 'CA1',...
            tetList{pfc}, 'PFC');
        tetrode.add(animal, sessionNum, "descrip",...
            [refList{hpcR} refList{hpcL}],  'CA1Ref',...
             refList{pfc},  'PFCRef');
    end

    % ---------------------------------- 
    % DEEPINSIGHT : (Spikes +  LFP data)
    % ---------------------------------- 
    % Dependencies : requieres tetrode information 
    if dodecode
        rawLib.create.deepinsightRaw(dayDir, animal, sessionNum,...
            'transpose', true);
        rawLib.append.behavior(animal, sessionNum,...
            'egocentric', [],...
            'tasktype', 'run',...
            'changefield', {'time','postime'},...
            'transpose', true);
        if domarks
            rawLib.append.marks(animal, sessionNum)
        end
    end

    % -----------------------
    % Rsync results to server
    % -----------------------
    % Most essential for large/huge 256 channel datasets ... remove the current folder working on and
    % pull the next folder from the server.
    if dorsync
        util.rsync.rawpush(animal, dayDirs{sessionNum}, rsync_kws{:}, 'deleteExpensiveFolders', ["mda", "rawmda","LFP","raw.LFP","raw"]); % pushes changes
        util.rsync.rawpush(animal, dayDirs{sessionNum+direction}, rsync_kws{:}); % pushes any updates in the next folder beforre pulling
        util.rsync.rawpull(animal, dayDirs{sessionNum+direction}, 'sessionNum', sessionNum+direction, rsync_kws{:}); % pull the next day of data
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
tetrode.update.tetinfo(Info.directDir,  animal);
cellLib.create.cellinfo(Info.directDir, animal); 
cellLib.create.multiinfo(Info.directDir, animal); 
coding.table.info(animal, 'cellinfo');
coding.table.info(animal, 'tetinfo');

