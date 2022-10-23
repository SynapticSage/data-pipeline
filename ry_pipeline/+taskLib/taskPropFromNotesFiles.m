function  T = taskPropFromNotesFiles(dayDir, animID, sessionNum, varargin)
% Creates a comments file with my epoch annotations

ip = inputParser;
ip.parse(varargin{:});
opt = ip.Results;


keyboard
notesfiles = dir(fullfile(dayDir, string(animID) + "_" + sessionNum + "*.notes"));

%% Add epoch data to each trodes comments file
task = ndBranch.load(animID,'task', 'indices', sessionNum);
indices = ndBranch.indicesMatrixForm(task);
if isempty(indices)
    error('no data point')
end
for notesfile = notesfiles'

    disp(sprintf('Props2Task: Procesing %s', notesfile.name));

    desc = readlines(fullfile(notesfile.folder, notesfile.name));
    desc = desc(~startsWith(desc,"#"), :);
    desc = desc(desc ~= "",:);

    day  = split(desc(startsWith(desc,"day"),:)," ");
    day  = str2double(day(2));
    epoch  = split(desc(startsWith(desc,"epoch"),:)," ");
    epoch  = str2double(epoch(2));

    taskEp = task{day}{epoch};

    for d = desc'
        d = split(d, " ");
        prop = d(1);
        prop = replace(prop, "-", "_");
        prop = replace(prop, "barriers", "barrier");
        value = join(d(2:end), " ");
        if all(isstrprop(value, 'digit'))
            value = str2double(value); 
        end
        taskEp.(prop) = value;
    end
    if taskEp.task == "sleep"
        taskEp.type = "sleep";
    else
        taskEp.type =  "run";
    end

    task = ndb.set(task, [day epoch], taskEp);
end
ndBranch.save(task, animID, 'task', 1)

