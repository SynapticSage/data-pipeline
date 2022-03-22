function preprocess(dataDir, matlabCallbackDir, animalid, dayDirs, varargin)
% callbackLib.preprocess generates callback data for a given animal
%
% dataDir : where to put the data
% matlabCallbackDir : where to find callback information
% animalid : animal id to lookfor
% dayDirs : day directories to match callbacks in matlabCallbackDir with (TIME CORRECTION STEP)

ip = inputParser;
ip.addParameter('mapping', []); %vector that maps from session number (for exp data) to the actual session number over (behavior + expt)
ip.parse(varargin{:});
opt = ip.Results;

fixed_folder = [dataDir filesep 'callback'];
if ~exist(fixed_folder, 'dir')
    mkdir(fixed_folder)
end

cdir = pwd;
onCleanup(@() cd(cdir));
cd(matlabCallbackDir);

% Make a list of possible session strings
sessions = [];
switch class(dayDirs)
    case {'cell','string'}
        pattern = '(?<session>[0-9]{2,3})_(?<date>[0-9]{6,9})';
        for s = 1:numel(dayDirs)
            R = regexp(dayDirs{s}, pattern, 'names');
            if isempty(R); continue; end
            possibleSessionStr{s} = [animalid '_' R.session];
            sessions(s) = string(R.session);
        end
        possibleSessionStr = string(possibleSessionStr);
    case {'double','single','int64','int32','int16'}
        sessions = dayDirs;
        possibleSessionStr = string(animalid) + "_" + sessions; 
    otherwise
        error("sessions variable is unsupported type");
end
sessions = sort(string(sessions));

% Loop over the possible matfiles
callback = [];
cnt = 0;
prog = ProgressBar(numel(sessions),  ...
                   'Title','Generating direct callback files');
cleanup = onCleanup(@() prog.release());
               
for file = dir('*.mat')'

    % Is this a mafile in the list of possible sessions?
    if ~any(arrayfun(@(x) contains(file.name, x), possibleSessionStr))
        continue
    end
    prog.step([],[],[]);

    % Compute properties of the session
    name = regular_expression(file.name);
    name.session = string(name.session);
    name.epoch   = str2double(name.epoch);
    if ~isempty(opt.mapping)
        prog.printMessage('change')
        name.session = opt.mapping(sessions == name.session);
    else
        name.session = find(sessions == name.session);
    end

    % Load up the matfile contents, correct the time, and place it into the structure
    try
        match_file = fullfile(file.folder, file.name);
        prog.printMessage(['Trying ' match_file])
        fix_args = {'searchdirectory', matlabCallbackDir};
        callback{name.session}{name.epoch} = callbackLib.fixCallbackTime(match_file, ...
            fix_args{:}, 'dispFun', @(x) prog.printMessage(x));
        callback{name.session}{name.epoch} = callback{name.session}{name.epoch};
        %file_exists = true;
        cnt = cnt+1;
    catch ME
        prog.printMessage('Exception caught')
        callback{name.session}{name.epoch} = [];
        %file_exists = false;
        prog.printMessage("Cause = " + ME.message)
        fprintf("Table => \n")
        prog.printMessage(struct2table(ME.stack))
    end
    if isstring(name)
        name = name.join('');
    end

    % Save callback structure
    callbackFile = fullfile(fixed_folder, sprintf('%s%s%02d-%02d.mat', animalid, 'callback', name.session, name.epoch));
    save(callbackFile, 'callback')
    
end

fprintf('%d callbacks processed\n', cnt);
save(fullfile(fixed_folder, [filesep animalid 'callback' '.mat']), ...
     'callback')

% --------------------------------------------------
function R = regular_expression(name)
% REGULAR_EXPRESSION parse regular expression for animal session epoch

    pattern = '(.*_)*(\()?(?<animal>\w*)_(?<session>\w*)_(?<epoch>\w*)(\))?(?<descriptor>_\w*)(\))?(?<ext>\..*)?';
    R = regexp(name, pattern, 'names');
