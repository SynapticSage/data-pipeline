function T = rhythmTable(animal, datatype, ind, varargin)

ip = inputParser;
ip.addParameter('addDatatypeCol', false);
ip.addParameter('addIndMetadata', true);
ip.addParameter('label', '');
ip.addParameter('folder', '');
ip.addParameter('tetrode', []);
ip.parse(varargin{:})
Opt = ip.Results;
ind_labels = ndbFile.datatypeLevels('eeg');
redund_labels = ["time", ind_labels, "Properties", "Row", "Variables"];

if iscell(datatype)
    assert(isa(Opt.label, 'cell'), "Must pass a cell type")
    T = cell(numel(datatype),1);
    for i = 1:numel(datatype)
        OptCopy = Opt;
        OptCopy.label = OptCopy.label{i};
        t = lfpLib.create.rhythmTable(animal, datatype{i}, ind, OptCopy);
        if i > 1
            columns = setdiff(string(fieldnames(t)), redund_labels);
            t = t(:, columns);
        end
        T{i} = t;
    end
    %T = util.cell.icat(T);
    T = cat(2, T{:});
else
    rhythm = ndb.load(animal, datatype, 'inds', ind);
    indices = ndb.indicesMatrixForm(rhythm);
    T = cell(size(indices,1), 1);
    cnt=0;
    for ind = progress(indices', 'Title', 'Building table')
        cnt=cnt+1;
        r = ndb.get(rhythm, ind);
        time = double(geteegtimes(r));
        time = time(:);
        raw   = r.data(:,1);
        if size(r.data,2) == 3
            phase = r.data(:,2);
            amp   = r.data(:,3);
            r = table(time, raw, phase, amp, ...
                'VariableNames', {'time', [Opt.label,'raw'], [Opt.label,'phase'], [Opt.label, 'amp']}); 
        else
            r = table(time, raw, ...
                'VariableNames', {'time', [Opt.label,'raw']}); 
        end
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
    for col in [Opt.label, 'raw']
        T.(col) = float32(T.(col));
    end
end

clearvars -except T % memory leak, so trying to reduce that here
util.notify.pushover('Finished rhythm table')
