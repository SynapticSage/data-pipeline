% Shows  rois around well
varargin={};
animal = 'RY16';
dayepoch=[36, 2];
varargin = {};
hash = string(DataHash( struct('animal',animal, 'dayepoch', dayepoch, 'varargin', varargin) ));
resize =  0.5;

%  _       _____ _   _ _   _ ___ _   _  ____   ____ ___ __________ ____  
% / |  _  |_   _| | | | \ | |_ _| \ | |/ ___| / ___|_ _|__  / ____/ ___| 
% | | (_)   | | | | | |  \| || ||  \| | |  _  \___ \| |  / /|  _| \___ \ 
% | |  _    | | | |_| | |\  || || |\  | |_| |  ___) | | / /_| |___ ___) |
% |_| (_)   |_|  \___/|_| \_|___|_| \_|\____| |____/___/____|_____|____/ 
%                                                                        
%  ___  _____  __        _______ _     _       ____   ___ ___ 
% / _ \|  ___| \ \      / / ____| |   | |     |  _ \ / _ \_ _|
%| | | | |_     \ \ /\ / /|  _| | |   | |     | |_) | | | | | 
%| |_| |  _|     \ V  V / | |___| |___| |___  |  _ <| |_| | | 
% \___/|_|        \_/\_/  |_____|_____|_____| |_| \_\\___/___|
%                                                             
%% ------------------------------------
% Point  here is just to make sure our well rois look alright before proceeding
% to do a video alignment

% get a frame where the animal is not covering our rois and checkpoint
singleFrameFile = fullfile(filesep, 'tmp', hash + "_singleFrame" + '.mat');
if ~exist(singleFrameFile, 'file')
    %  Get positions where  the animal in the center  of the track, to
    %  not occlude the wells
    inds = posLib.quantileLocation(animal, dayepoch, 'x',[0.45 0.55],...
        'y', [0.45 0.55]);
    ind = find(inds, 1, 'first');

    [frame, ~, cmperpix] = videoLib.framesFromInd(animal, dayepoch, ind);
    M = matfile(fullfile(filesep, 'tmp', hash + '.mat'),...
        'Writable', true);
    M.frame = frame;
else
    M = matfile(singleFrameFile);
    frame = M.frame;
end

% Grab well data
% --------------
task = ndBranch.load(animal, 'task', 'indices', dayepoch);
task = ndb.get(task, dayepoch);
welllocs = task.maze.welllocs;

maze = task.maze;
if strcmp(maze.units,'px')
    welllocs = maze.welllocs*cmperpix;
end

roi = [6.5 6.5]; % Cm Width Height
roi_radius = max(roi)/2;

% Crop
rects =  [(welllocs - roi/2), repmat(roi,size(welllocs,1),1)]; % compute in CM
rects = (rects/cmperpix)*resize; % bring back to pixels
rects = round(rects);

% Crop out each wellloc image
[widthWim, heightWim] = size(frame,[1,2]);
cmxax = (1:widthWim) * cmperpix * resize;
cmyax = (1:heightWim) * cmperpix * resize;
nWells = size(welllocs,1);

fig('Well ROI Check');
wellim   = [];
for w = 1:nWells
    axs(w) = subplot(nWells, 1, w);
    tmp =  imcrop(frame, rects(w,:));
    wellim(:,:,:,w) = tmp;
    axes(axs(w))
    image(cmxax(1:size(tmp,1)), cmyax(1:size(tmp,2)), tmp);
    xlabel('cm')
    ylabel('cm')
    title(sprintf('Well %d', w));
end
sgtitle('Well ROI Check');

%  ____         ____    _    ____ _____ _   _ ____  _____ 
% |___ \   _   / ___|  / \  |  _ \_   _| | | |  _ \| ____|
%   __) | (_) | |     / _ \ | |_) || | | | | | |_) |  _|  
%  / __/   _  | |___ / ___ \|  __/ | | | |_| |  _ <| |___ 
% |_____| (_)  \____/_/   \_\_|    |_|  \___/|_| \_\_____|
%                                                         
%     _    _     _       _____ ____      _    __  __ _____ ____  
%    / \  | |   | |     |  ___|  _ \    / \  |  \/  | ____/ ___| 
%   / _ \ | |   | |     | |_  | |_) |  / _ \ | |\/| |  _| \___ \ 
%  / ___ \| |___| |___  |  _| |  _ <  / ___ \| |  | | |___ ___) |
% /_/   \_\_____|_____| |_|   |_| \_\/_/   \_\_|  |_|_____|____/ 
%                                                                
% Get all frames: let's checkpoint this!
if ~exist('tmp','dir')
    mkdir('tmp')
end
allFrameFile = fullfile(filesep, './tmp', string(hash) + "_allFrame" + '.mat');
if exists(allFrameFile, 'file')
    [frames, idx, cmperpix] = videoLib.framesFromInd('RY16', 36, 'all', 'resize', resize, 'matfile', allFrameFile) % Requests to return entire video frame set (in compressed uint8)
    frames = num2cell(frames, 1:3);
    frames = frames(:)';
    M = matfile(allFrameFile,'Writable', true);
    M.cmperpix = cmperpix;
    M.animal = animal;
    M.dayepoch= dayepoch;
    M.resize = resize;
else
    M = matfile(allFrameFile, 'Writable', true);
    frames = M.frames;
    cmperpix = M.cmperpix;
    animal = M.animal;
    dayepoch = M.dayepoch;
    resize = M.resize;
end

% Obtain the statistics over time

% Make a video
newFrames = cell(1,size(frames,4));
axs=[];
clf
for f = progress(1:size(frames,4))
    axs = register.well.roiPlot(axs, rects, frames(:,:,:,f));
    pause(0.1);
    F = getframe(gcf);
    newFrames{f} =F;
end

%  _____       _____      _                  _     
% |___ /   _  | ____|_  _| |_ _ __ __ _  ___| |_   
%   |_ \  (_) |  _| \ \/ / __| '__/ _` |/ __| __|  
%  ___) |  _  | |___ >  <| |_| | | (_| | (__| |_ _ 
% |____/  (_) |_____/_/\_\\__|_|  \__,_|\___|\__( )
%                                               |/ 
%  _                        __                        
% | |_ _ __ __ _ _ __  ___ / _| ___  _ __ _ __ ___    
% | __| '__/ _` | '_ \/ __| |_ / _ \| '__| '_ ` _ \   
% | |_| | | (_| | | | \__ \  _| (_) | |  | | | | | |_ 
%  \__|_|  \__,_|_| |_|___/_|  \___/|_|  |_| |_| |_( )
%                                                  |/ 
%                            _           
%   ___ ___  _ ____   _____ | |_   _____ 
%  / __/ _ \| '_ \ \ / / _ \| \ \ / / _ \
% | (_| (_) | | | \ V / (_) | |\ V /  __/
%  \___\___/|_| |_|\_/ \___/|_| \_/ \___|

task = ndb.get(ndb.load('RY16', 'task', 'indices', dayepoch), dayepoch);
epochfilter = diotable.day == dayepoch(1) & diotable.epoch == dayepoch(2);
epochdiotable = diotable(epochfilter,:);

% Get video signal
% ----------------
videoSignal = register.well.quantile(frames, rects, 'ploton', false);
videoSignal = num2cell(videoSignal,1);
videoTime = task.video.timestamps;
names     = ["time", "well_" + (1:5)];
videoSignal = table(videoTime, videoSignal{:}, ...
    'VariableNames', names);

% Ready matrices to convolve at same sampling rate
% ------------------------------------------------
[dioSignal, dioTime, videoSignal, videoTime] = ...
    register.equalize.returnMatrices(epochdiotable, videoSignal, 1000);
[offset, timeOffset] = register.computeDelay(dioTime, dioSignal, videoTime, videoSignal,...
    'ploton', false);

% Finally, let's apply changes to diotable
% ----------------------------------------
dio = ndb.load(animal, 'dio', 'indices',  dayepoch, 'asTidy', true);
dio = ndb.addConst(dio, 'indexOffset', offset, 'indices', dayepoch, 'addToExisting', true);
dio = ndb.addConst(dio, 'timeOffset', timeOffset, 'indices', dayepoch, 'addToExisting', true);
dio = ndb.nest(dio, ["indexOffset","timeOffset"], 'correction', 'indices', dayepoch);
diotable(epochfilter,:).time = diotable(epochfilter,:).time + timeOffset;
ndb.save(dio, animal, 'dio', 1);
ndb.save(diotable, animal, 'diotable', 1);
