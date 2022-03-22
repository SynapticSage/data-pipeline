function varargout = framesFromInd(animID, dayepoch, videoindex, varargin)
% get video  frames  that best match time list t for animal animID
% dayepoch : numeric
%   Day dayepoch

ip = inputParser;
ip.KeepUnmatched = true;
timeSourceValidation = @(x) isstring(x) || ischar(x) || isnumeric(x);
ip.addParameter('timeSource', 'videoTimeStamps', timeSourceValidation); % Possible sources pos | videoTimeStamps | numeric
ip.parse(varargin{:});
opt = ip.Results;
Params = ip.Unmatched;

if ischar(opt.timeSource)
    opt.timeSource=string(opt.timeSource);
end

if ~(iscolumn(dayepoch)  || isrow(dayepoch)  && numel(dayepoch) > 0)
    error('Index is wronge shape or wrong  size')
end

% CASE: user provides day and epoch and frame integeers
if numel(dayepoch) ==  2  && string(videoindex) ~= "all"

    videoobj = videoLib.returnVideo(animID, dayepoch(1), dayepoch(2));
    Params.indices = videoindex;
    if nargout == 0
        videoLib.frameread(videoobj, Params);
    elseif nargout == 1
        [frameset{1}]  = videoLib.frameread(videoobj, Params);
    elseif ismember(nargout, [2,3])
        [frameset{1}, idxset{1}]  = videoLib.frameread(videoobj, Params); % if nargout 2, then we're getting only unique frames and the indices neeeded to map those into the requested time set
    else
        error("Improper number of outputs")
    end
    rawpos = ndBranch.load(animID, 'rawpos', 'indices', dayepoch);
    rawpos = ndBranch.get(rawpos, dayepoch);
    cmperpixel = rawpos.cmperpixel;

% CASE: user provides day and epoch and asks for  ALL  frames
elseif numel(dayepoch) ==  2  && isequal(string(videoindex),"all")

    [data, cmperpixel] = videoLib.frameDat(animID, dayepoch);
    videoobj = videoLib.returnVideo(animID, dayepoch(1), dayepoch(2));
    Params.indices = data(data.day==dayepoch(1) & data.epoch==dayepoch(2),:).epochIndex;
    if nargout == 0
        videoLib.frameread(videoobj, Params);
    elseif nargout == 1
        [frameset{1}]  = videoLib.frameread(videoobj, Params);
    elseif ismember(nargout, [2,3])
        [frameset{1}, idxset{1}]  = videoLib.frameread(videoobj, Params); % if nargout 2, then we're getting only unique frames and the indices neeeded to map those into the requested time set
    else
        error("Improper number of outputs")
    end

% CASE: user provides only day
elseif numel(dayepoch) ==  1
    
    [data, cmperpixel] = videoLib.frameDat(animID, dayepoch);
    % data([false;  diff(times)==0],:) = [];   % Delete any frametimes that have dups

    % If dayepoch includes epoch, index  within the epoch (1:lastTimeinEpoch),
    % else, index across epochs (1:lastTimeInSession)
    % -----------------------------------------------

    if string(videoindex) ~= "all"
        inds = ismember(videoindex, data.overallInd);
        data = data(inds,:); % we want the following frames
    end

    % For each group of day epochs
    % ----------------------------
    [groups, day, epoch] = findgroups(data.day, data.epoch); % Find groups of day and epoch
    uGroups = unique(groups)';                       % Extract the unique group numbers
    if nargout == 2
        idxset   = cell(1,numel(uGroups));
    end

    for g = uGroups
        inds = groups == g;
        videoobj = videoLib.returnVideo(animID, day(g), epoch(g));
        Params.indices = data(inds, 'epochIndex');
        if nargout == 0
            videoLib.frameread(videoobj, Params);
        elseif nargout == 1
            [frameset{g}]  = videoLib.frameread(videoobj, Params);
        elseif ismember(nargout, [2,3])
            [frameset{g}, idxset{g}]  = videoLib.frameread(videoobj, Params);
        else
            error("Improper number of outputs")
        end
    end
end

% Convert outputs from cell to matrix, and place into varargin
% ------------------------------------------------------------
if nargout >= 1
    frames = cat(4,frameset{:});
    varargout{1} = frames;
end
if nargout >= 2
    idxset(2:numel(idxset)) = arrayfun(@(x) max(idxset{x-1}) + idxset{x}, 2:numel(idxset),'UniformOutput',false); % if we have multiple sets, when they're glued together,  we need to shift indices to account for that glueing
    idx = cat(1,idxset{:});
    varargout{2} = idx;
end
if nargout >= 3
    % Let's include cmperpix, to help  user with describing distance in their video
    varargout{3} = cmperpixel;
end

% Lastly, if user made a matfile with frames instead of output with opt.matfile, let's add the relevant dataframe
if isfield(Params,'matfile') && ~isempty(Params.matfile)
    [data, cmperpixel] = videoLib.frameDat(animID, dayepoch);
    M = matfile(Params.matfile,'Writable',true);
    M.data = data;
    M.cmperpixel = cmperpixel;
end

