function [frames, M] = get(animID, dayepoch, varargin)
% Handles returning the video frames
%
% Returns
% -------
% frames : X x Y x Channel x time
% M : matfile reference if cached

ip = inputParser;
ip.KeepUnmatched = true;
ip.addParameter('cache', true); % whether to cache the video for future plots
ip.addParameter('global', false); % whether to cache the video for future plots
ip.parse(varargin{:})
Opt = ip.Results;
NewOpt = ip.Unmatched; % All other keywords are passed onto the video object

if ~isfield(NewOpt, 'resize')
    NewOpt.resize = 0.25;
end
NewOptVarg = util.struct2varargin(NewOpt);

% Get all frames: let's checkpoint this!
allFrameFile = videoLib.checkpointName(animID, dayepoch, NewOptVarg{:});
disp("All frame file => " + allFrameFile);

if Opt.global
    global frames
    if ~exist(allFrameFile,'file')
        frames = [];
    end
else
    frames = [];
end

if ~exist(allFrameFile, 'file')
    disp('Pre-fetching in video...')
    videoLib.framesFromInd(animID, dayepoch, ...
        'all',...
        NewOptVarg{:},...
        'matfile', allFrameFile) % Requests to return entire video frame set (in compressed uint8)
    M = matfile(allFrameFile,'Writable', true);
    %frames = num2cell(M.frames, 1:3);
    %frames = frames(:)';
    frames       = M.frames;
    cmperpix = posLib.getCmperpix(animID, dayepoch);
    M.cmperpixel = posLib.getCmperpix(animID,dayepoch);
    M.animal     = animID;
    M.dayepoch   = dayepoch;
    M.resize     = NewOpt.resize;
else
    disp('Reading video from checkpoint');
    tic
    M = matfile(allFrameFile, 'Writable', true);
    if isempty(frames)
        frames = M.frames;
    end
    toc
end

