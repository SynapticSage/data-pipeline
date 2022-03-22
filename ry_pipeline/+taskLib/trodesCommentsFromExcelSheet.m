function trodeCommentsFromExcelSheet(dayDir, animID, tableFile, sessionNum, varargin)
% Creates a comments file with my epoch annotations

ip = inputParser;
ip.addParameter('matchMethod',     "epoch-str")
ip.addParameter('ext',             '.potential')
ip.addParameter('sheet',           'Recordings')
ip.addParameter('epochTableField', 'epoch_track_str')
ip.parse(varargin{:});
opt = ip.Results;

if nargin < 4
    sessionNum = split(dayDir,"_");
    sessionNum = str2double(sessionNum(1));
    warning('sessionNum left blank so using %d', sessionNum);
end

% Read in the excel or csv
tableFile = string(tableFile);
if tableFile.endsWith("csv")
    SheetOpt = detectImportOptions();
    T = readtable(tableFile, SheetOpt);
elseif tableFile.endsWith(["xls","xlsx"])
    SheetOpt = detectImportOptions(tableFile, "Sheet", opt.sheet);
    charTypes = cellfun(@(x) isequal(x,'char'), SheetOpt.VariableTypes);
    SheetOpt.VariableTypes(charTypes) = {'string'};
    T = readtable(tableFile, SheetOpt);
else
    error("Improper table file type")
end

%% Obtain epoch boundaries with default 1 sec gap
cd(dayDir);
cleanupFunction = onCleanup(@(x) cd(currdir));
[epochTimes, files_with_offsets] = getEpochs(1);  %assumes that there is at least a 1-second gap in data between epochs if no .trodesComments file is found
if isempty(files_with_offsets) && ~isempty(epochTimes)
    tmp = dir('*.trodesComments');
    filenames = string({tmp.name});
else
    filenames = string({files_with_offsets.file});
end


%% Add epoch data to each trodes comments file
for file = filenames

    [path,name,ext] = fileparts(file);

    switch char(opt.matchMethod)
        case 'day-ep'
        day = split(dayDir,"_");
        day = str2double(day(1));
        filter = T.day == day && T.epoch == ecnt
        case 'epoch-str'
        filter = table2array(T(:,opt.epochTableField)) == name;
        assert(any(filter), ...
            sprintf('No matching epoch with opt.matchMethod = %s', opt.matchMethod))
        otherwise
            error('invalid matchMethod')
    end

    % Get the relevant line of the table and write trode descriptions about them
    t = T(filter,:);
    commentLib.addDescriptor(file, ["task", "barrier", "tracking_method"], t);
end

