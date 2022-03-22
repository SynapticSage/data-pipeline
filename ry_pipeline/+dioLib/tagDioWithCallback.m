function dio = tagDioWithCallback(dio, maze)
% Tags dio with the callback info
% 
% returns data as a table if not already one

if ~istable(dio)
    dio = ndBranch.toTidy(dio);
end

% Add raw number as column
if ismember("id", string(dio.Properties.VariableNames) )
    num = dio.id.replace("Dout","").replace("Din ","").replace(" ","");
    num = str2double(num);
    dio.num = num;
    dio(:,'id') = [];
end
if ismember(string(dio.Properties.VariableNames), "direction" )
    dio.dir = dio.direction;
    dio(:,'direction') = [];
end

if nargin > 1
    % Add maze info to dio
    label    = strings(height(dio), 1);
    platform = zeros(height(dio), 1, 'uint8');
    region   = strings(height(dio), 1);
    for field = string(fieldnames(maze.dio))'
        toLabel = ismember(dio.num, maze.dio.(field));
        label(toLabel) = field;
        I = bsxfun(@eq, maze.dio.(field), dio.num(toLabel));
        [I,~] = find(I'); % CRTICAL! The transposition step required, it will fail if [~,I] = find(I);
        platform(toLabel) = maze.ordering.platforms(I);
    end
    dio.location = platform;
    dio.type = label;
    for field = string(fieldnames(maze.platform))'
        toLabel = ismember(dio.location, maze.platform.(field));
        region(toLabel)  = field;
    end
    dio.region = region;
end
