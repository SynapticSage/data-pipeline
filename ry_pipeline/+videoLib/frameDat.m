function [data, cmperpixel] = frameDat(animID, day)
% REturn a table encoding video frame information for a day of data

task = ndBranch.load(animID, 'task', 'indices', day);
task = ndBranch.unnest(task, 'video', 'cmperpixel'); % Move this field into the main struct
data = cellfetch(task,'video'); % fetch  data fields
inds =   data.index;            % get day of data fields
if ~isempty(inds)
    data =  data.values;
    % Create columns of epochIndex, videoTimes, dayEpochNum
    data = arrayfun(@(x) [(1:numel(data{x}.timestamps))',...
        data{x}.timestamps(:),...
        x*ones(size(data{x}.timestamps(:)))],...
        1:numel(data),...
        'UniformOutput', false);
    data = cat(1,data{:});
    data = num2cell(data,1);
    data = table(data{:},...
        'VariableNames', {'epochIndex', 'videoTimes', 'dayEpochNum'});
else
    error("Not implemented")
end

data.day   = inds(data.dayEpochNum, 1); % get day
data.epoch = inds(data.dayEpochNum, 2); % get epoch
data.overallInd = (1:height(data))';
assert(issorted(data.videoTimes));

if nargout > 1
    cmperpixel = cellfetch(task,'cmperpixel'); % fetch  data fields
    cmperpixel = median(cat(1,cmperpixel.values{:}));
end                              
