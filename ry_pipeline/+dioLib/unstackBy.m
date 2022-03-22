function dio = unstackBy(dio, valueField, unstackField, varargin)

ip = inputParser;
ip.addParameter('technique', 'table'); % matrix, table
ip.addParameter('rmfield', string([]));
ip.parse(varargin{:})
Opt = ip.Results;

Opt.rmfield = string(Opt.rmfield);
for field = Opt.rmfield(:)'
    if ismember(field, dio.Properties.VariableNames)
        dio.(field) = [];
    end
end

switch Opt.technique
    case 'table'
        newVariableNames = valueField + "_" + unstackField + "_" + unique(dio.(unstackField));
        dio = unstack(dio, valueField, unstackField, 'NewDataVariableNames', newVariableNames);
    case 'matrix'
        dio = sortrows(dio, {'day','epoch','time'});
        uFields = unique(dio.(unstackField));
        data = arrayfun(@(field) (dio(dio.(unstackField)  == field,:).curve), uFields,...
            'UniformOutput',false);
        time = arrayfun(@(field) (dio(dio.(unstackField)  == field,:).time), uFields,...
            'UniformOutput',false);
end
