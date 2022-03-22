function rmfield(animID, dayepoch, rmfields, varargin)
% Appends behavior data to the raw file for deepinsight

ip = inputParser;
ip.addParameter('changefield', {});
ip.parse(varargin{:})
Opt = ip.Results;

indices = ndbFile.indicesMatrixForm(animID, 'deepinsight', 'indices', dayepoch);

if nargin < 4
    fields = string([]);
end

for ind = progress(indices','Title','Field removal');
    day   = ind(1);
    epoch = ind(2);
    
    %Open matfile for raw results
    resultFile = sprintf('%s/RAW/%sdeepinsight%02d-%02d.mat', ...
                         ndbFile.animdir(animID), animID, day, epoch);
    M = matfile(resultFile, 'Writable', true);
    
    % Remove the fields
    fields = string(fieldnames(M));
    for field = fields(:)'
        if ismember(field, rmfields)
            util.matfile.rmvar(M.Properties.Source,char(field));
        end
    end

    % Close the file
    clear M;
end
