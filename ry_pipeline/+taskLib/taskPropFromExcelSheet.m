function  T = taskPropFromExcelSheet(dayDir, animID, tableFile, sessionNum, varargin)
% Creates a comments file with my epoch annotations

ip = inputParser;
ip.addParameter('matchMethod',     "epoch-str")
ip.addParameter('ext',             '.potential')
ip.addParameter('sheet',           'Recordings')
ip.addParameter('epochTableField', 'epoch_track_str')
ip.addParameter('dayFromDayDir',   false);
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

%% Add epoch data to each trodes comments file
task = ndBranch.load('RY16','task', 'indices', sessionNum);
indices = ndBranch.indicesMatrixForm(task);
if isempty(indices)
    error('no data point')
end
for index = indices'

    disp(sprintf('Props2Task: Procesing %02d-%02d', index));
    taskEp = ndBranch.get(task, index);

    day = index(1);
    epoch = index(2);
    if opt.dayFromDayDir
        [~, day_dayStr, ~] = fileparts(dayDir);
        day_dayStr = split(day_dayStr,"_");
        day_dayStr = str2double(day_dayStr(1));
        filter = T.day == day_dayStr & T.epoch == epoch;
    else
        filter = T.day == day & T.epoch == epoch;
    end
    if ~any(filter)
        warning('Day %02d - Ep %02d  not found ...', day, epoch)
    end

    % Get the relevant line of the table and write trode descriptions about them
    t = T(filter,:);
    taskEp = taskLib.addDescriptor(taskEp, ["task", "barrier", "tracking_method"], t);
    if taskEp.task == "sleep"
        taskEp.type = "sleep";
    else
        taskEp.type =  "run";
    end
    task = ndb.set(task, index, taskEp);
end
ndBranch.save(task, 'RY16', 'task', 1)

