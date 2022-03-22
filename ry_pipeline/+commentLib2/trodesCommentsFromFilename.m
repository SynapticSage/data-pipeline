function [frames, times] = frames(animID, index, time)
% Requires : task  file  to store name of mp4 and videoTimeStamps for
% an animal.

ip = inputParser;
ip.addParameter('folder', []);  % folder where to  search for files
ip.addParameter('videoTimeStamps', "fromPos")  % options : "fromPos", "fromVideo"
ip.parse(varargin{:});
opt = ip.Results;
animInfo = animaldef(animID);
animFolder =  animInfo{2};

% Where to search for the video
if isempty(opt.folder)
    if exist(fullfile(animFolder,'video'),'dir')
        opt.folder = fullfile(animFolder,'video');
    elseif exist(fullfile(animFolder, '..', animID),'dir')
        opt.folder = fullfile(animFolder, '..', animID);
    end
end

% Acquire name of video file from the task struct
task = load(sprintf('%s/%stask.mat',animFolder, animID));

currdir = pwd;
cd(opt.folder);
file = subdir(task{day}{epoch}.video);
cd(currdir);

if numel(file) == 0
    error("Cannot find %s video in path %s", task{day}{epoch}.video, opt.folder)
elseif numel(file) > 1
    error("Too many %s videos in path %s", task{day}{epoch}.video, opt.folder)
end

switch char(opt.videoTimeStamps)
    case  'fromPos'
        videoTimes = load(sprintf('%s/%spos%02d.mat',animFolder, animID, day));
    case 'fromVideo'
    otherwise
end

[frames, times] = videoLib.read(file.name, videoTimes, time)
