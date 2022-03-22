function behavior(animID, dayepoch, datatype, fields, varargin)
% Appends behavior data to the raw file for deepinsight

ip = inputParser;
ip.addParameter('dataname', 'deepinsight');
ip.addParameter('changefield', {});
ip.addParameter('transpose', false);
ip.addParameter('tasktype', []);
ip.parse(varargin{:})
Opt = ip.Results;

behavior = ndb.load(animID,  datatype,...
    'indices',dayepoch);
behaviorInds = ndb.indicesMatrixForm(behavior);
rawInds = ndbFile.indicesMatrixForm(animID, Opt.dataname, 'indices', dayepoch);
indices =  intersect(rawInds, behaviorInds, 'rows');
m = min(size(indices,2), size(dayepoch,2));
indices =  indices(ismember(indices(:,m), dayepoch(:,m), 'rows'),:);

if ~isempty(Opt.tasktype)
    task = ndb.load(animID, 'task', 'indices', dayepoch);
    task = cellfetch(task,'type');
    task.index = task.index(string(task.values)=="run",:);
    indices = intersect(indices, task.index, 'rows');
end

if nargin < 4
    fields = string([]);
end

for ind = progress(indices','Title',sprintf('Adding %s fields',datatype));
    day   = ind(1);
    epoch = ind(2);
    
    B = ndb.get(behavior, ind);
    if isempty(fields)
        fields  = string(fieldnames(B));
    end

    %Open matfile for raw results
    resultFile = sprintf('%s/RAW/%s%s%02d-%02d.mat', ...
                         ndbFile.animdir(animID), animID, Opt.dataname, day, epoch);
    disp(resultFile)
    disp("Opening matfile")
    M = matfile(resultFile, 'Writable', true);
    disp("done")
    
    % Add the fields
    for field = progress(fields(:)','Title','behavior fields')
        if isempty(Opt.changefield) || ~ismember(field, Opt.changefield(:,1))
            F = field;
        else
            F = Opt.changefield{ismember(field,Opt.changefield(:,1)),2};
        end
        if Opt.transpose
            M.(F) =  B.(field)';
        else
            M.(F) =  B.(field);
        end
    end

    % Close the file
    clear M;
end
