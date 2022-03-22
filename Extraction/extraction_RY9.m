%% Libaries!
addpath(genpath('~/Code/pipeline/TrodesToMatlab'))
addpath(genpath('~/Code/pipeline/SpikeGadgets'))
addpath(genpath('~/Code/pipeline/pipeline-filterframework'))
addpath(genpath('~/Code/pipeline/TrodesExtractionGUI'))
addpath(genpath('~/Code/pipeline/preprocess'))
addpath(genpath('~/Code/Src_Matlab/ry_Utility'))

%% Setup Extraction script
% Define animal directory and day directories to extract
%animal_dir     = '/media/ryoung/Thalamus/ry_GoalCoding_Project/RY9_experiment/RY9'
animal_dir = '/Volumes/FastData/ry_GoalCoding_Project/RY9_experiment/RY9'
animal_out_dir = '/Volumes/FastData/ry_GoalCoding_Project/RY9_experiment/RY9'
%animal_out_dir = '/media/ryoung/Thalamus/ry_GoalCoding_Project/RY9_experiment/RY9'
dayDirs = {'55_20190725',...
            '56_20190727',...
            '57_20190729',...
            '58_20190730',...
            '59_20190731',...
            '60_20190801',...
            '61_20190802',...
            '62_20190803',... 
            '63_20190804',... 
            '64_20190805',... 
            '65_20190807',... 
            '66_20190808',... 
            '67_20190809',... 
            '68_20190811'} 

%ZG:9 epochs in total, as it is in RY7's extraction script

% Define file prefixes, used to fix filenames in a day_dir and for creating
% export folders
% #FIX_FILENAMES
prefixes = {'RY9_55_day01',...
            'RY9_56_day02',...
            'RY9_57_day03',...
            'RY9_58_day04',...
            'RY9_59_day05',...
            'RY9_60_day06',...
            'RY9_61_day07',...
            'RY9_62_day08',...
            'RY9_63_day09',...
            'RY9_64_day10',...
            'RY9_65_day11',...
            'RY9_66_day12',...
            'RY9_67_day13',...
            'RY9_68_day14'}
           
% Define config files, empty string uses config in rec for extraction
% #TRODESCOMMENTS #EXPORT
configFiles = repmat({['~/Configs/RY9', filesep, 'RY9_fix.trodesconf']}, numel(prefixes), 1);
%ZG: just changed all 7 to 9

% Set Rec Order for each day folder
% #EXPORT
RecOrder = {
           {'RY9_55_02.rec'},...
           {'RY9_56_01.rec','RY9_56_02.rec'},...
           {'RY9_57_01.rec','RY9_57_02.rec', 'RY9_57_03.rec'},...
           {'RY9_58_01.rec','RY9_58_02.rec','RY9_58_03.rec','RY9_58_04.rec'},...
           {'RY9_59_01.rec','RY9_59_02.rec','RY9_59_03.rec','RY9_59_04.rec','RY9_59_05.rec','RY9_59_06.rec'},...
           {'RY9_60_01.rec','RY9_60_02.rec','RY9_60_03.rec','RY9_60_04.rec','RY9_60_05.rec'},...
           {'RY9_61_01.rec','RY9_61_02.rec','RY9_61_03.rec','RY9_61_04.rec'},...
           {'RY9_62_01.rec','RY9_62_02.rec','RY9_62_03.rec','RY9_62_04.rec'},...
           {'RY9_63_01.rec','RY9_63_02.rec','RY9_63_03.rec','RY9_63_04.rec','RY9_63_05.rec'},...
           {'RY9_64_01.rec','RY9_64_02.rec','RY9_64_03.rec','RY9_64_04.rec','RY9_64_05.rec'},...
           {'RY9_65_02.rec','RY9_65_03.rec','RY9_65_04.rec','RY9_65_05.rec'},... % missing video timestamps for 1st sleep, so removing
           {'RY9_66_01.rec','RY9_66_02.rec','RY9_66_03.rec','RY9_66_04.rec','RY9_66_05.rec'},...
           {'RY9_67_01.rec','RY9_67_02.rec','RY9_67_03.rec'},...
           {'RY9_68_01.rec','RY9_68_02.rec','RY9_68_03.rec'},...
           }
%ZG: included all the run and sleep rec files from those 5 days
% Export types and customFlags for each export function
% #EXPORT
exportTypes =    {'LFP','mda','dio','time'};
exportFlgs = cell(length(exportTypes), 1);
%exportFlgs{1} = '-outputrate 15000';
%exportTypes =      {'spikes','LFP','time','dio','mda','phy'};
%exportTypes =      {'raw','LFP','dio','spikes'};
%exportFlgs = {'',...
%    '',...
%    ''};

% Max parallel jobs for Matclust file generation
% #MATLCUST
maxParallelJobs = 8;

%% Loops through dayDirs and execute extraction in each folders
% #BODY
nDays = numel(dayDirs);
dayStart = find(contains(dayDirs,'55_'));
dayStop  = find(contains(dayDirs,'55_'));
nExport = numel(exportTypes);
progExport = ProgressBar(nExport, 'Title', 'Exports')
progDays = ProgressBar(dayStop-dayStart+1, 'Title', 'Days')
for iExport=1:nExport
    for iDay=dayStart:dayStop
        disp("Day " + iDay + " export " + exportTypes{iExport});
        %try
        cd(animal_dir);
        day = dayDirs{iDay};
        dayDir = fullfile(animal_out_dir, day);
        disp(['Running extraction script in ' day])
        cd(day);
        fnMask = prefixes{iDay};
        %fnMask = dayDirs{iDay};
        % if we actually don't want to replace names, so just set fnMask to
        % old_prefix later on.
        keep_name = true;

        if iExport == 1
            % Setup log
            mkdir('Logs/')
            logFile = ['Logs/' date() '_' prefixes{iDay} '_ExtractionLog.log'];
            diary(logFile)

            % Fix Filenames and Change prefix
            % #FIX_FILENAMES
            disp('Fixing Filenames...')
            [~,old_prefix] = RN_fixFilenames(dayDirs{iDay}, 0);
        end

        % Fix Rec names if needed
        % #TRODESCOMMENTS #EXPORT
        sortedRecs = RecOrder{iDay};
        if ~keep_name && ~strcmp(fnMask,old_prefix)
            sortedRecs = cellfun(@(x) strrep(x,old_prefix,fnMask),sortedRecs,...
            'UniformOutput',false);
        end
        
        if iExport == 1

            % Create Trodes Comments
            % #TRODESCOMMENTS
            %commentLib.createTrodesComments(sortedRecs);
            [validation, fixed] = ry_validateAndFixFolder(dayDir, 'pruneUnnecessaryComments', true);
        end

        % Make Common Flag
        % #EXPORT
        commonFlag = '';
        if ~isempty(configFiles{iDay})
            commonFlag = [' -reconfig ' configFiles{iDay}];
        end
        out_dir = fullfile(animal_out_dir, dayDirs{iDay});
        commonFlag = [' -rec ' strjoin(sortedRecs,' -rec ') commonFlag ' -outputdirectory ' out_dir ' -output ' fnMask];

        % Run exports
        % #EXPORT
        if iDay == 1 && iExport < 2
            continue
        end
        disp(['Exporting ' exportTypes{iExport} '...'])
        RN_exportBinary(exportTypes{iExport},[commonFlag ' ' exportFlgs{iExport}], ...
            'background_execute', false)
        %catch ME
        %    disp("Matlab error caught on day " + iDay)
        %    ME
        %    struct2table(ME.stack);
        %end
        progDays.step([],[],[])
    end
    progExport.step([],[],[])
end

