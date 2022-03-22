function ml_process_animal_marks(animID, rawDir, varargin)
% Processes just the marks alone, if not done. ml_process_animal by default now
% also does this step, so this may not be needed.

ip = inputParser;
ip.addParameter('sessionNums', []);
ip.addParameter('daysToProcess', []);
ip.addParameter('tet_list', []);
ip.addParameter('tet_options', []); % Takes a tet option struct from ry_ml_tetoption.m
ip.addParameter('mask_artifacts', true);
ip.addParameter('dayDirs', []);
ip.addParameter('viewMatclust', false);
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
k0 = 1;
for k=k0:numel(resDirs)
    rD = resDirs{k};
    diary([rD filesep 'ml_sorting.log'])
    fprintf('\n\n------\nBeginning creation of marks for %s\nDate: %s\n\nBandpass Filtering, Masking out artifacts and Whitening...\n------\n',rD,datestr(datetime('Now'))); 

    ml_create_marks(rD);

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
