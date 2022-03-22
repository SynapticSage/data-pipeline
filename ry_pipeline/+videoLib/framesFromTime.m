function varargout = framesFromTime(animID, index, t, varargin)
% get video  frames  that best match time list t for animal animID
%
% index : numeric
%   Day index

ip = inputParser;
timeSourceValidation = @(x) isstring(x) || ischar(x) || isnumeric(x);
ip.addParameter('format', {"uint8"}, @(x) iscell(x) || isstring(x) || ischar(x)); % Possible sources pos | videoTimeStamps | numeric
ip.addParameter('timeSource', 'videoTimeStamps', timeSourceValidation); % Possible sources pos | videoTimeStamps | numeric
ip.parse(varargin{:});
opt = ip.Results;
if ischar(opt.timeSource)
    opt.timeSource=string(opt.timeSource);
end

if ~(iscolumn(index)  || isrow(index)  && numel(index) > 0)
    error('Index is wronge shape or wrong  size')
end

animInfo = animaldef(animID);

currdir =  pwd;
cleaup = onCleanup(@()  cd(currdir));

cd(animInfo{2});

if opt.timeSource == "pos"
    posfile = sprintf('%s/%spos%02d.mat', animInfo{2:3}, index(1))
    if exist(posfile,'file')
        load(posfile, 'pos');
        data = cellfetch(pos,'data'); % fetch  data fields
        inds =   data.index;            % get index of data fields
        data =  data.values;           % get valuees of those data fields
        data =  arrayfun(@(x) [(1:size(data{x},1))', data{x}, ones(size(data{x},1),1)*x],...
            1:numel(data),...
            'UniformOutput',false); % add column saying which index of frame and dayep
    else
        opt.timeSource="videoTimeStamps";
    end
end
if  opt.timeSource ==  "videoTimeStamps"
    taskfile = sprintf('%s/%stask%02d.mat', animInfo{2:3}, index(1));
    load( taskfile, '-mat', 'task');
    data = cellfetch(task,'video'); % fetch  data fields
    inds =   data.index;            % get index of data fields
    if ~isempty(inds)
        data =  data.values;
        data = arrayfun(@(x) [(1:numel(data{x}.timestamps))',...
            data{x}.timestamps(:),...
            x*ones(size(data{x}.timestamps(:)))],...
            1:numel(data),...
            'UniformOutput', false);
    else
        error("Not implemented")
    end
end
data = cat(1,data{:});
data  =  data(:,[1 2 end]);                  % get data and element memership
data(:,end:end+1)  =  inds(data(:,end),:); % transform membeership into day epoch
times = data(:,2);

assert(issorted(times));

data([false;  diff(times)==0],:) = []; % Delete any frametimes that have dups
times = data(:,2);

% Match times  reqeusted to timeind/time/day/epoch rows
if numel(t)>1
    inds = interp1(times, 1:size(times,1), t, 'nearest');
else
    [~,inds] = min(abs(t-times));
end
inds(isnan(inds)) = [];
if isempty(inds)
    error("No frames  found")
end
data = data(inds,:); % we want the following frames

% For each group of day epochs
dayepoch = data(:,end-1:end);
times = data(:,2);
dayepoch = num2cell(dayepoch, 1);
[groups, day, epoch] = findgroups(dayepoch{:});
uGroups = unique(groups)';
frameset = cell(1,numel(uGroups));
if nargout == 2
    idxset   = cell(1,numel(uGroups));
end
for g = uGroups
    inds = groups == g;
    videoobj = videoLib.returnVideo(animID, day(g), epoch(g));
    if nargout == 1
        [frameset{g}]  = videoLib.frameread(videoobj, 'indices', data(inds,1), 'format',opt.format);
    elseif nargout == 2
        [frameset{g}, idxset{g}]  = videoLib.frameread(videoobj, 'indices', data(inds,1), 'format',opt.format); % if nargout 2, then we're getting only unique frames and the indices neeeded to map those into the requested time set
    else
        error("Improper number of outputs")
    end
end

frames = cat(4,frameset{:});
varargout{1} = frames;

if nargout == 2
    idxset(2:numel(idxset)) = arrayfun(@(x) max(idxset{x-1}) + idxset{x}, 2:numel(idxset),'UniformOutput',false); % if we have multiple sets, when they're glued together,  we need to shift indices to account for that glueing
    idx = cat(1,idxset{:});
    varargout{2} = idx;
end
