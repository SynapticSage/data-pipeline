function [fixed] = fixCallbackTime(filename, varargin)
% FIX_GOALMAZE_MATFILES sets the time in the callbacks such that it registers to
% post-processed data
% Inputs
% ------
% filename : str or char array
%   partial name of file to fix
%
% Name-value optionals
% --------------------
% searchdirectory : str or char
%   Directory to search for needed files
% 
% mastercommentfile : bool
%   Whether or not to figure out resets from a master file or files
%   that correspond to each rec file
%
% Precautions
% --------
% Depends on fixing the files in the exact order they were recorded.
%
% Tips
% ----
% Search directory needs to be high up enough to find mat files and
% the rec/videoTimeStamps
%
% If you pass in the absolute path to the matfile that needs to be
% corrected, you can skip one of the file search steps.
%
% Returns
% -------
% fixed structure of variables

%% Optional input
%opt = struct('searchdirectory', pwd, 'mastercommentfile', falseip = inputParser;
ip = inputParser;
ip.addParameter('searchdirectory', pwd);
ip.addParameter('mastercommentfile', false);
ip.addParameter('dispFun', @disp);
ip.parse(varargin{:})
opt = ip.Results;

%% Enter obtain primary search term and enter search directory
% -----------------------------------------------
cdir = pwd;
[~, name, ~] = fileparts(filename);
name = regular_expression(name);
name = [name.animal '_' name.session '_' name.epoch];
if isstring(name)
    name = char(name.join(''));
end
opt.dispFun(['Search key  = ' name]);
cd(opt.searchdirectory)
% -----------------------------------------------

%% Find matlab file and LOAD
% -----------------------------------------------
if ~contains(filename, '.mat')
    opt.dispFun('Looking for matchfile...')
    warning off;
    match = subdir(['*' char(name) '*.mat']);
    warning on;
    assert(~isempty(match), "Uh oh, callback not found -- no file to fix!")
    filename = match(end).name;
end
warning off;
dat = load(filename);
warning on;
opt.dispFun(['Opening ' filename])
% -----------------------------------------------

%% Process reset
% -----------------------------------------------
fixed  = fix_times(dat, name);
cd(cdir) % return home
% -----------------------------------------------

% --------------------------------------------------
function R = regular_expression(name)
% REGULAR_EXPRESSION parse regular expression for animal session epoch

    pattern = '(.*_)*(\()?(?<animal>\w*)_(?<session>\w*)_(?<epoch>\w*)(\))?(?<ext>\..*)?';
    R = regexp(name, pattern, 'names');

% --------------------------------------------------
function [offset,noOffsetFound] = find_offset(name)
% GET_INITIAL_TIME returns the first time of the previous file

    R = regular_expression(name);

    offset_file_filter = [R.animal '_' R.session '_' R.epoch ...
        '.offset.txt'];
    if isstring(offset_file_filter)
         offset_file_filter = offset_file_filter.join('');
     end

    warning off
    match = subdir(char(offset_file_filter));
    warning on;
    if length(match) < 1 
        warning('Offset file not found -- assuming offset = 0')
        offset = 0;
        noOffsetFound = 1;
    elseif length(match) > 1
        error('More or less than one offset file found!')
    else
        opt.dispFun('Finding offset')
        offset_fid = fopen(match.name);
        offset = fscanf(offset_fid, '%d');
        fclose(offset_fid);
        noOffsetFound = 0;
    end

% --------------------------------------------------
function dat = fix_times(dat, name)
% FIX_TIMES performs the actual time fix on the dat

    [initial_time, offset_missing] = find_offset(name);
    % Fix older time record fields
    time_fields = {'htime', 'time', 'atime', 'ztime', 'ptime', 'ctime', 'btime', 'wtime', 'stime'};
    for field = time_fields
        field = field{1};
        if isfield(dat.perf, field)
            % Time in seconds is ECU_times / ECU_samprat + MCU_offsets/MCU_samprat
            dat.perf.(field) = dat.perf.(field)/1e3 + initial_time/30e3;
        end
    end
    % Fix table field
    if isfield(dat.perf, 'table')
        % Time in seconds is ECU_times / ECU_samprat + MCU_offsets/MCU_samprat
        dat.perf.table.time = dat.perf.table.time/1e3 + initial_time/30e3;
    end
    dat.perf.rec_offset = initial_time;
    dat.perf.rec_missing_offset_file = offset_missing;
