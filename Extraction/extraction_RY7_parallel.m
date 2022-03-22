% Libaries!
addpath('~/Code/Pipeline/TrodesToMatlab')
addpath('~/Code/Pipeline/SpikeGadgets')
addpath('~/Code/Pipeline/pipeline-filterframework')
addpath('~/Code/Pipeline/TrodesExtractionGUI')


%% Setup Extraction script
% Define animal directory and day directories to extract
animal_dir = '/media/ryoung/Thalamus/ry_GoalCoding_Project/RY7_experiment/RY7'
day_dirs = {'64_20190418',...
            '65_20190419',...
            '66_20190420',...
            '67_20190421',...
            '68_20190422',...
            '69_20190423'}

% Define file prefixes, used to fix filenames in a day_dir and for creating
% export folders
% #FIX_FILENAMES
prefixes = {'RY7_64_',...
            'RY7_65_',...
            'RY7_66_',...
            'RY7_67_',...
            'RY7_68_',...
            'RY7_69_'}

% Define config files, empty string uses config in rec for extraction
% #TRODESCOMMENTS #EXPORT
configFiles = {[animal_dir, filesep, 'ry7.trodesconf'],...
               [animal_dir, filesep, 'ry7.trodesconf'],...
               [animal_dir, filesep, 'ry7.trodesconf'],...
               [animal_dir, filesep, 'ry7.trodesconf'],...
               [animal_dir, filesep, 'ry7.trodesconf'],...
               [animal_dir, filesep, 'ry7.trodesconf']};

% Set Rec Order for each day folder
% #EXPORT
RecOrder = {
           {'RY7_64_02.rec','RY7_64_03.rec'},...
           {'RY7_65_01.rec'},...
           {'RY7_66_01.rec','RY7_66_02.rec','RY7_66_03.rec','RY7_66_04.rec'},...
           {'RY7_67_01.rec','RY7_67_02.rec','RY7_67_03.rec','RY7_67_04.rec'},...
           {'RY7_68_01.rec','RY7_68_02.rec', 'RY7_68_03.rec'},...
           {'RY7_69_01.rec','RY7_69_02.rec','RY7_69_03.rec'},...
           }

% Export types and customFlags for each export function
% #EXPORT
%exportTypes =      {'spikes','LFP','time','dio','mda','phy'};
%exportTypes =      {'raw','LFP','dio','spikes'};
exportTypes = {'time'};
exportFlgs  = cell(length(exportTypes), 1);

% Set flags for raw, if its there
for iExport = 1:numel(exportTypes)
    if isequal(exportTypes{iExport}, 'raw')
        exportFlgs{iExport} = '-outputrate 30000';
    end
end

% Max parallel jobs for Matclust file generation
% #MATLCUST
maxParallelJobs = 8;

%% Loops through day_dirs and execute extraction in each folders
% #BODY
nDays = numel(day_dirs);
nExport = numel(exportTypes);
for iExport=1:nExport
    for iDay=3:3

        cd(animal_dir);
        day = day_dirs{iDay};
        disp(['Running extraction script in ' day])
        cd(day);
        %fnMask = prefixes{iDay};
        fnMask = day_dirs{iDay}

        if iExport == 1
            % Setup log
            mkdir('Logs/')
            logFile = ['Logs/' prefixes{iDay} '_ExtractionLog.log'];
            diary(logFile)

            % Fix Filenames and Change prefix
            % #FIX_FILENAMES
            disp('Fixing Filenames...')
            [fnMask,old_prefix] = RN_fixFilenames(day_dirs{iDay}, 0);
        end

        % Fix Rec names if needed
        % #TRODESCOMMENTS #EXPORT
        sortedRecs = RecOrder{iDay};
        if ~strcmp(fnMask,old_prefix)
            sortedRecs = cellfun(@(x) ...
                strrep(x,old_prefix,fnMask),...
                sortedRecs,...
                'UniformOutput',false);
        end
        
        if iExport == 1

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
        commonFlag = [' -rec ' strjoin(sortedRecs,' -rec ') commonFlag ' -output ' fnMask];

        % Run exports
        % #EXPORT
        if iDay == 1 && iExport < 2
            continue
        end

        disp(['Exporting ' exportTypes{iExport} '...'])
        RN_exportBinary(exportTypes{iExport},[commonFlag ' ' exportFlgs{iExport}], ...
            'background_execute', true)

    end

    %RY_waitForExports()
end
