function T = rhythmTable(animal, datatype, ind, varargin)

ip = inputParser;
ip.addParameter('addDatatypeCol', false);
ip.addParameter('addIndMetadata', true);
ip.parse(varargin{:})
Opt = ip.Results;

ind_labels = ndbFile.datatypeLevels('eeg');

rhythm = ndb.load(animal, datatype, 'inds', ind);
indices = ndb.indicesMatrixForm(rhythm);
T = cell(size(indices,1), 1);
cnt=0;
for ind = progress(indices', 'Title', 'Building table')
    cnt=cnt+1;
    r = ndb.get(rhythm, ind);
    time = single(geteegtimes(r));
    time = time(:);
    raw = r.data(:,1);
    phase = r.data(:,2);
    amp = r.data(:,3);
    r = table(time, raw, phase, amp); 
    if Opt.addIndMetadata
        for i = 1:numel(ind_labels)
            r.(ind_labels(i)) = repmat(uint8(ind(i)), height(r), 1);
        end
    end
    rhythm = ndb.set(rhythm, ind, []);
    T{cnt} = r;
end
T = cat(1, T{:});
T = util.table.castefficient(T);
util.notify.pushover('Finished rhythm table')
