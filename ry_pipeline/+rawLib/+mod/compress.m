function compress(animID, dayepoch, varargin)
% Compresses single-format data in the mda files

ip = inputParser;
ip.addParameter('overwrite', false);
ip.parse(varargin{:})
Opt = ip.Results;

tetinfo = ndb.load(animID,'tetinfo','indices',dayepoch);
tiInds  = ndb.indicesMatrixForm(tetinfo);
rawInds = ndbFile.indicesMatrixForm(animID, 'mda', 'indices', dayepoch);
indices =  intersect(rawInds, tiInds(:,1:2), 'rows');

for ind = indices'
    day = ind(1);
    epoch  =  ind(2);
    resultFile = sprintf('%s/RAW/%smda%02d-%02d.mat', ...
                         ndbFile.animdir(animID), animID, day, epoch);
    M = matfile(resultFile, 'Writable', true);
    datSize = size(M,'data');
    for channel = 1:datSize(2)
    end
end
