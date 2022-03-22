function T = taskTable(animal, ind, varargin)

ip = inputParser;
ip.addParameter('addIndMetadata', true);
ip.parse(varargin{:})
Opt = ip.Results;

ind_labels = ndbFile.datatypeLevels('task');

task = ndb.load(animal, 'task', 'inds', ind);
indices = ndb.indicesMatrixForm(task);

T = cell(size(indices,1), 1);
cnt=0;
for ind = progress(indices', 'Title', 'Building task table')
    cnt=cnt+1;
    epoch = ndb.get(task, ind);

    x=[]; y=[]; name=[];
    for field = string(fieldnames(epoch.maze))'
        if isa(epoch.maze.(field),'double') && size(epoch.maze.(field),2) > 1
            x = [x; epoch.maze.(field)(:,1)];
            y = [y; epoch.maze.(field)(:,2)];
            name = [name; repmat(string(field), size(epoch.maze.(field),1), 1)];
        end
    end

    t = table(x, y, name); 
    if Opt.addIndMetadata
        for i = 1:numel(ind_labels)
            t.(ind_labels(i)) = repmat(uint8(ind(i)), height(t), 1);
        end
    end
    t.start = repmat(epoch.starttime, height(t), 1);
    t.end = repmat(epoch.endtime, height(t), 1);
    t.task = repmat(epoch.task, height(t), 1);
    t.type = repmat(epoch.type, height(t), 1);

    T{cnt} = t;

end
T = cat(1, T{:});
T = util.table.castefficient(T);
util.notify.pushover('Finished task table')

