%% Libaries!
addpath(genpath('~/Code/pipeline/TrodesToMatlab'))
addpath(genpath('~/Code/pipeline/SpikeGadgets'))
addpath(genpath('~/Code/pipeline/pipeline-filterframework'))
addpath(genpath('~/Code/pipeline/TrodesExtractionGUI'))
addpath(genpath('~/Code/pipeline/preprocess'))
addpath(genpath('~/Code/pipeline/ry_pipeline'))
addpath(genpath('~/Code/Src_Matlab/ry_Utility'))

%% Setup Extraction script
% -------------- WHAT/WHERE TO PROCESS ------------------
% Define animal directory and day directories to extract
animalRawDir = '/Volumes/FastData/ry_GoalCoding_Project/RY16_experiment/RY16_fix'
animalRawDirOut = '/Volumes/FastData/ry_GoalCoding_Project/RY16_experiment/RY16_fix'
%animalRawDir    = '/Volumes/GenuDrive/RY16_fix'
%animalRawDirOut = '/Volumes/GenuDrive/RY16_fix'
[dayDirs, sessionList] = ry_selectDays('/Volumes/Calyx/RY16_fix/', 45, 69)

% Define file prefixes, used to fix filenames in a day_dir and for creating
% #FIX_FILENAMES
prefixes = ["RY16_"] + string(sessionList)' + "_expDay" + compose("%02d",sessionList-min(sessionList)+1)';
prefixes = cellstr(prefixes(:));
           
configFiles = repmat({'~/Configs/RY16/RY16_fix.trodesconf'}, ...
                      numel(dayDirs), 1);

recOrder = ry_generateRecOrder(animalRawDir, dayDirs,...
    'exclusions', [],...
    'skipNonexist', true)
           
% -------------- WHAT TO EXPORT ------------------
exportTypes =       {'spikes'};
%exportTypes =       {'mdaraw'};
%exportTypes =       {'dio'};
%exportTypes =       {'LFP', 'mda', 'time'};
%exportTypes =       {'LFP'};
%exportTypes =       {'mda','raw','time'};
exportFlgs = cell(length(exportTypes), 1);
%exportTypes =      {'spikes','LFP','time','dio','mda','phy'};
%exportTypes =      {'raw','LFP','dio','spikes'};
%exportTypes =      {'time', 'dio'};
for iType = 1:numel(exportTypes)
    if strcmp(exportTypes{iType}, 'raw')
        exportFlgs{iType} = '-outputrate 30000 -userawrefs 1';
    elseif strcmp(exportTypes{iType}, 'lfpraw')
        exportFlgs{iType} = '-outputrate 30000 -userefs 1 -oneperntrode 0 -usespikefilters 0 -uselfpfilters 0';
    elseif strcmp(exportTypes{iType}, 'LFP')
        exportFlgs{iType} = '-userefs 0 -oneperntrode 1 -uselfpfilters 1';
    elseif strcmp(exportTypes{iType}, 'mdaraw')
        exportFlgs{iType} = '-userefs 1 -usespikefilters 0'; 
    end
end

% -------------- HOW TO COMPUTE ------------------
% Max parallel jobs for Matclust file generation
maxParallelJobs = 8;

%% Loops through dayDirs and execute extraction in each folders

% Number of days
nDays = numel(dayDirs);
dayStart = find(contains(dayDirs,'???'));
dayStop  = find(contains(dayDirs,'???'));

% number of data types to export
nExport = numel(exportTypes);

% Progress bars
ProgressBar.deleteAllTimers()
progExport = ProgressBar(nExport, ...
    'Title', 'Exports');
progDays = ProgressBar(dayStop-dayStart+1, 'Title', 'Days');

% Flags
deepFilenameChange = false; % whether to go beyond simple filename curation (e.g. removal of .2) 
                            % into changing recfiles to their prefixes as specified above!  for iExport=1:nExport
for iExport=1:nExport

    firstDataExport = iExport == 1;
    for iDay=dayStart:dayStop
        printMessage(progDays, "Day " + iDay + " export " + exportTypes{iExport});
        %try
            cd(animalRawDir);
            day = dayDirs{iDay};
            printMessage(progDays, ['Running extraction script in ' day])
            cd(day);

            if firstDataExport
                % Setup log
                if ~exist('Logs/','dir')
                    mkdir('Logs/')
                end
                logFile = ['Logs/' date() '_' prefixes{iDay} '_ExtractionLog.log'];
                diary(logFile)

                % Fix Filenames and Change prefix
                % #FIX_FILENAMES
                printMessage(progDays, 'Fixing Filenames...')
                [~ , old_prefix] = RN_fixFilenames(dayDirs{iDay}, deepFilenameChange);
            end
            fnMask = prefixes{iDay};

            % Fix Rec names if needed
            % #TRODESCOMMENTS #EXPORT
            sortedRecs = recOrder{iDay};
            if deepFilenameChange && ~isequal(fnMask,old_prefix)
                printMessage(progDays, 'Rec file names were changed')
                sortedRecs = cellfun(@(x) strrep(x,old_prefix,fnMask),sortedRecs,...
                'UniformOutput',false);
            else
                printMessage(progDays, 'Unchanged')
            end
            
            if firstDataExport
                % Create Trodes Comments
                % #TRODESCOMMENTS
                RN_createTrodesComments(sortedRecs);
            end

            % Make Common Flag
            % #EXPORT
            commonFlag = '';
            if ~isempty(configFiles{iDay})
                commonFlag = [' -reconfig ' configFiles{iDay}];
            end
            % Output into another file system or dir structure? (for BIG data)
            if exist('animalRawDirOut', 'var') && ~isempty(animalRawDirOut)
                out_dir = fullfile(animalRawDirOut, dayDirs{iDay});
            else
                out_dir = pwd;
            end
            %commonFlag = [' -rec $(realpath ' strjoin(sortedRecs,') -rec $(realpath ') ') -outputdirectory ' out_dir commonFlag ' -output ' fnMask];
            if isequal(exportTypes{iExport},'lfpraw')
                commonFlag = [' -rec ' strjoin(sortedRecs,' -rec ') commonFlag ' -outputdirectory ' out_dir ' -output ' fnMask '.raw'];
                export = 'LFP';
            elseif isequal(exportTypes{iExport},'mdaraw')
                commonFlag = [' -rec ' strjoin(sortedRecs,' -rec ') commonFlag ' -outputdirectory ' out_dir ' -output ' fnMask '.raw'];
                export = 'mda';
            else
                commonFlag = [' -rec ' strjoin(sortedRecs,' -rec ') commonFlag ' -outputdirectory ' out_dir ' -output ' fnMask];
                export = exportTypes{iExport};
            end
            % Run exports
            % #EXPORT
            printMessage(progDays, ['Exporting ' exportTypes{iExport} '...'])
            RN_exportBinary(export, [commonFlag ' ' exportFlgs{iExport}], ...
                'background_execute', false)
        %catch ME
            %progDay.printMessage("Matlab error caught on day " + iDay)
        %end
        progDays.step([],[],[])
    end
    if mod(iExport,2) == 0
        %RY_waitForExports()
    end
    progExport.step([],[],[])

end
