function ml_process_animal(animID, rawDir, varargin)
% ml_process_animal(animID,rawDir,varargin) will setup, preprocess and
% spike sort data with mountainlab-js. rawDir is the raw data directory
% containing the day directories. It is expected that mda files were
% extracted from the rec files already.
% Requires that day directories inside the rawDir are named day_date (e.g. 01_180819)
% and that the mda directory inside the day dirs is labelled
% animID_day_date.mda or animID_day_date_epoch.mda (the latter will only
% happen if you have 1 epoch), [e.g. RW9_02_1808224.mda]
% This function will create a MountainSort directory in the direct folder.
% Inside that directories will be .mountain directories for each day with
% subdirectories for the sorting data for each tetrode. Logs will be
% created in each tetrode directory, and finally tetrode information will
% be combined into a spikes mat-file in FilterFramework format for each
% day. To avoid overwriting existing clustering, the spikes file will the
% saved in the .mountain folder for each day.
%
% NAME-VALUE Pairs:
%   dataDir     : path to direct folder for animal. default = rawDir/../animID_direct
%
%   sessionNums : array of days to request to process, of some larger set.
%                   default = [] processes all days in rawDir
%
%   tet_list    : array of tetrodes to cluster. default = [] processes all tetrodes available
%
%   mask_artifacts      : flag whether to mask artifacts before whitening.
%                         default = 1, but the function errors rarely on some tetrodes (no idea
%                         why yet) so you can choose not to do this process
%                         *Actually, currently the script is setup to automatically 
%                         skip artfact masking if it errors, this is mentioned at the end 
%                         of the log file. so Check Your Logs!
%
%   viewMatclust: toggles creation of matclust files from the munged mda  files
%
%   dayDirs     : optionally provide list of directories to process
% ---------------------------------------------------------
%
%   daysToProcess : optionally provide list of session numbers to correspond to
%                   those given dayDirs

ip = inputParser;
ip.addParameter('sessionNums', []);
ip.addParameter('daysToProcess', []);
ip.addParameter('tet_list', []);
ip.addParameter('tet_options', []); % Takes a tet option struct from ry_ml_tetoption.m
ip.addParameter('mask_artifacts', true);
ip.addParameter('dayDirs', []);
ip.addParameter('viewMatclust', false);
ip.addParameter('extractmarks', true); % Whether to extract marks.mda
ip.addParameter('overwrite', false); % Whether to overwrite existing ms files detected at various stages
ip.addParameter('dataDir', []);
ip.addParameter('pat', '(?<anim>[A-Z]+[0-9]+)_(?<day>[0-9]{2})_(?<date>[0-9]+)_*(?<epoch>[0-9]*)(?<epoch_name>\w*).mda'); % Regular expression for parsing mda folders, if a user decides to use a different folder structure
ip.parse(varargin{:})
Opt = ip.Results;

% RYAN :because  of  space limitations, users may not be able to keep their
% direct folder nested in the experiment folder (perhaps in the server, but not
% on very limited  hard disks). Adding ability to specifiy direct.
if isempty(Opt.dataDir)
    if rawDir(end)==filesep
        rawDir = rawDir(1:end-1);
    end
    dataDir = [fileparts(rawDir) filesep animID '_direct'];
else
    dataDir = char(Opt.dataDir);
end

%% DETERMINE DAY  DIRECTORIES
% IF user provides dayDirs, use them, otherwise, compute them!
% ------------------------------------------------------------
if isempty(Opt.dayDirs)
    dayDirs = dir(rawDir);
    daysToProcess = zeros(numel(dayDirs),1);
    for k=numel(dayDirs):-1:1
        if strcmpi(dayDirs(k).name,'.') || strcmpi(dayDirs(k).name,'..')
            daysToProcess(k) = -1;
        else
            pat = '(?<day>[0-9]{2})_(?<date>\d*)';
            parsed = regexp(dayDirs(k).name,pat,'names');
            if isempty(parsed)
                disp(['Could not parse directory name: ' dayDirs(k).name])
                dn = input('What day is this (#)?  ');
            else
                dn = str2double(parsed.day);
            end
            daysToProcess(k) = dn;
        end
    end
    dayDirs(daysToProcess<0) = [];         % The day directory string names
    daysToProcess(daysToProcess<0) = [];   % Corresponding number index of the
                                           % day/session for _direct folder, -1
                                           % for skip
    % Compute the full paths
    dayDirs = string({dayDirs.folder}) + filesep + string({dayDirs.name}) + filesep;
else
    dayDirs = string(Opt.dayDirs);                 % The day directory string names
    if Opt.daysToProcess
        daysToProcess = Opt.daysToProcess; % Corresponding number index of the
                                           % day/session for _direct folder, -1
                                           % for skip
    else
        daysToProcess = 1:numel(dayDirs);  % Corresponding number index of the
                                           % day/session for _direct folder, -1
                                           % for skip
    end
end


% Subset requested session/day numbers
% TODO: fix this, not restricting days properly
if ~isempty(Opt.sessionNums)
    missing = setdiff(Opt.sessionNums,daysToProcess);
    [rmvDays,rmv] = setdiff(daysToProcess,Opt.sessionNums);
    dayDirs(rmv) = [];
    daysToProcess(rmv) = [];
    if ~isempty(missing)
        disp('Could not find data for days:')
        disp(missing)
    end
end

% Instruct user of program choices
disp('Processing raw data with mountain lab. Processing:')
disp(dayDirs')
if ~isempty(Opt.tet_list)
    disp('restricting to tetrodes:')
    disp(Opt.tet_list')
end
%pause(10)

% ---------------------------------------------------------
% Run mda_util, returns list of tetrode results directories
% ---------------------------------------------------------
[resDirs, tetrodePerDir] = mda_util(cellstr(dayDirs),...
    'tet_list',Opt.tet_list,...
    'dataDir',dataDir,...
    'pat', Opt.pat);
dayResDirs = cell(numel(dayDirs),1);
dayIdx = 1;
maskErrors = zeros(numel(resDirs),1);

% --------------------------------
% For each day and tet sort spikes
% --------------------------------
%k0 = 34;
%warning(['K0 = ' num2str(k0)]);
k0 = 1;
for k=k0:numel(resDirs)

    rD = resDirs{k};

    diary([rD filesep 'ml_sorting.log'])
    fprintf('\n\n------\nBeginning analysis of %s\nDate: %s\n\nBandpass Filtering, Masking out artifacts and Whitening...\n------\n',rD,datestr(datetime('Now'))); 
    
    % -----------------------
    % Filter, Mask and Whiten
    % -----------------------
    % TODO: Add check to make sure there is data in the mda files, maybe up in mda_util
    if ~isempty(Opt.tet_options)
        tetrode = tetrodePerDir(k);
        if isempty(Opt.tet_options(tetrode).area)
            warning("No area on tetrode: skipping")
            continue
        end
        kws = {'freq_min', Opt.tet_options(tetrode).freq_min,...
               'freq_max', Opt.tet_options(tetrode).freq_max,...
               'tet_option', Opt.tet_options(tetrode)};
    else
        kws = {};
    end 

    [out,maskErrors(k)] = ml_filter_mask_whiten(rD, 'mask_artifacts', Opt.mask_artifacts,...
        'overwrite', Opt.overwrite, kws{:});

    % returns path to pre.mda.prv file
    fprintf('\n\n------\nPreprocessing of data done. Written to %s\n------\n',out)
    fprintf('\n------\nBeginning Sorting and curation...\n------\n')

    % Sort and Curate(?)
    % ------------------
    out2 = ml_sort_on_segs(rD, 'overwrite', Opt.overwrite, 'extractmarks', Opt.extractmarks);
    % returns paths to firings_raw.mda, metrics_raw.json and firings_curated.mda
    %fprintf('\n\nSorting done. outputs saved at:\n    %s\n    %s\n    %s\n',out2{1},out2{2},out2{3})
    fprintf('\n\n------\nSorting done. outputs saved at:\n    %s\n    %s\n------\n',out2{1},out2{2})

    % Delete intermediate files
    % -------------------------
    %if ~keep_intermediates
    %    tmpDir = '/tmp/mountainlab-tmp/';
    %    disp('Removing intermediate processing mda files...')
    %    delete([tmpDir '*.mda'])
    %end

    % Create matclust params file: Not Needed, only for trying to view spikes in matclust 5/8/19
    % ------------------------------------------------------------------------------------------
    if Opt.viewMatclust
        fprintf('\n\n------\nCreating Matclust Params and Waves files\n------\n')
        out3 = generateMatclustFromMountainSort(rD);
        fprintf('\n\n------\nFile creation done. outputs saved at:\n    %s\n    %s\n------\n',out3{1},out3{2})
    end

    % Cleanup
    % -------
    if maskErrors(k)
        fprintf('\n######\nMasking error for this day. Masking Artifacts skipped. Spikes may be noisy\n######\n')
    end

    diary off

    % check if container results folders is already in dayResDirs and add if not
    if rD(end)==filesep
        rD = rD(1:end-1);
    end
    dD = fileparts(rD);
    if ~any(strcmpi(dayResDirs,dD))
        dayResDirs{dayIdx} = dD;
        dayIdx = dayIdx+1;
    end
end
fprintf('Completed automated clustering!\n')
