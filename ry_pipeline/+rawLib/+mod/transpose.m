function transpose(animID, dayepoch, tfields, varargin)
% Appends behavior data to the raw file for deepinsight

ip = inputParser;
ip.addParameter('dataname','deepinsight');
ip.addParameter('changefield', {});
ip.addParameter('checkpoint', 'tcheck');
ip.addParameter('tasktype', []);
ip.parse(varargin{:})
Opt = ip.Results;

indices = ndbFile.indicesMatrixForm(animID, 'deepinsight', 'indices', dayepoch);

if ~isempty(Opt.tasktype)
    task = ndb.load(animID, 'task', 'indices', dayepoch);
    task = cellfetch(task,'type');
    task.index = task.index(string(task.values)=="run",:);
    indices = intersect(indices, task.index, 'rows');
end


if nargin < 3
    tfields = string([]);
end

for ind = progress(indices','Title','Matfiles');
    day   = ind(1);
    epoch = ind(2);
    
    %Open matfile for raw results
    resultFile = sprintf('%s/RAW/%s%s%02d-%02d.mat', ...
                         ndbFile.animdir(animID), animID, Opt.dataname, day, epoch);
    M = matfile(resultFile, 'Writable', true);
    if isempty(tfields)
        TF = setdiff(fieldnames(M),{'Properties','Source'});
    else
        TF = tfields;
    end

    if ismember(Opt.checkpoint, fieldnames(M))
        continue
    end
    
    % Remove the fields
    fields = string(fieldnames(M));
    for field = progress(fields(:)', 'Title', 'Fields')
        if ismember(field, TF)
            tmp =  M.(field);
            M.(field) = tmp';
        end
    end

    M.(Opt.checkpoint) = true;

    % Close the file
    clear M;
end
