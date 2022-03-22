function generateTable(rawpos, varargin)
% Generates table from rawpos

header = [rawpos.dataheader, rawpos.likelihoodheader];
data   = [rawpos.data, rawpos.likelihood];

linker = " ";
header = header(1,:) + linker + header(2,:);

data = num2cell(data, [2]);

T =  table(data{:}, 'VariableNames', header);
