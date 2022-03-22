function offsetDio(animal, dayepoch, varargin)
% Correct DIO offset for one epoch

ip = inputParser;
ip.addParameter('makeMovie', false);      % Hoow much to resize video before operating on it
ip.addParameter('ploton', true);          % Hoow much to resize video before operating on it
ip.addParameter('interactive', false);    % Hoow much to resize video before operating on it
ip.addParameter('resize', 0.25);          % Hoow much to resize video before operating on it
ip.addParameter('skipIfCorrection', true) % Hoow much to resize video before operating on it
ip.addParameter('startDayEpoch', [])      % Hoow much to resize video before operating on it
ip.parse(varargin{:})
Opt = ip.Results;
close all;

if isempty(Opt.startDayEpoch)
    startReached = true;
else
    startReached = false;
end

task = ndBranch.load(animal, 'task',...
                    'indices', dayepoch);
dayepochs = ndb.indicesMatrixForm(task);
tasktypes = cellfetch(task,'task');
tasktypes.values = cellfun(@(x) squeeze(char(string(x))), tasktypes.values,'UniformOutput',false);
tasktypes.values = util.str.flexConvert(tasktypes.values);
taskfilter = ismember(tasktypes.values,["cm","c","cmb"]);
dayepochs = dayepochs(taskfilter,:);
for dayepoch = dayepochs'

    if ~isempty(Opt.startDayEpoch) && ~startReached ...
            && isequal(Opt.startDayEpoch(:), dayepoch(:))
        startReached = true;
    end
    if ~startReached
        continue
    end

    hash = DataHash( struct('animal',animal, 'dayepoch', dayepoch, 'resize', Opt.resize));
    hash = string(hash);
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
    disp("Single frame file => " + singleFrameFile);
    if ~exist(singleFrameFile, 'file')
        %  Get positions where  the animal in the center  of the track, to
        %  not occlude the wells
        inds = posLib.quantileLocation(animal, dayepoch, 'x',[0.45 0.55],...
            'y', [0.45 0.55]);
        ind = find(inds, 1, 'first');

        [frame, ~, cmperpix] = videoLib.framesFromInd(animal, dayepoch, ind, 'resize',  Opt.resize);
        M = matfile(fullfile(filesep, 'tmp', hash + '.mat'),...
            'Writable', true);
        M.frame = frame;
        M.cmperpix = cmperpix;
    else
        M = matfile(singleFrameFile);
        frame = M.frame;
        cmperpix = M.cmperpix;
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

    %roi = [6.5 6.5]; % Cm Width Height
    roi = [7 7]; % Cm Width Height
    %roi = [8, 8]; % Cm Width Height
    roi_radius = max(roi)/2;

    % Crop
    rects = [(welllocs - roi/2), repmat(roi,size(welllocs,1),1)]; % compute in CM
    rects = (rects/cmperpix)*Opt.resize; % bring back to pixels
    rects = round(rects);

    % Crop out each wellloc image
    [widthWim, heightWim] = size(frame,[1,2]);
    cmxax = (1:widthWim) * cmperpix * Opt.resize;
    cmyax = (1:heightWim) * cmperpix * Opt.resize;
    nWells = size(welllocs,1);

    if Opt.ploton
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
        sgtitle(sprintf('Well ROI Check day %d epoch %d\n\n', dayepoch));
        fig('Well ROI Check Track')
        register.well.roiPlot([], rects, frame);
        sgtitle(sprintf('Track-Well ROI Check day %d epoch %d\nROI size = (%2.1fcm, %2.1fcm)\n\n', dayepoch, roi));
    end
    if Opt.interactive
        input("Does this look alright?",'s');
    end
    %keyboard

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
    disp("All frame file => " + allFrameFile);
    if ~exist(allFrameFile, 'file')
        disp('Pre-fetching in video...')
        tic
        videoLib.framesFromInd(animal, dayepoch, 'all',...
            'resize', Opt.resize,...
            'matfile', allFrameFile) % Requests to return entire video frame set (in compressed uint8)
        M = matfile(allFrameFile,'Writable', true);
        %frames = num2cell(M.frames, 1:3);
        %frames = frames(:)';
        frames  = M.frames;
        M.cmperpixel = cmperpix;
        M.animal = animal;
        M.dayepoch= dayepoch;
        M.resize = Opt.resize;
        toc
    else
        disp('Reading video from checkpoint');
        tic
        M = matfile(allFrameFile, 'Writable', true);
        frames = M.frames;
        try
        cmperpix = M.cmperpixel;
        animal = M.animal;
        dayepoch = M.dayepoch;
        Opt.resize = M.resize;
        end
        toc
    end

    % Obtain the statistics over time

    % Make a video
    if Opt.makeMovie
        newFrames = cell(1,size(frames,4));
        axs=[];
        clf
        for f = progress(1:size(frames,4))
            axs = register.well.roiPlot(axs, rects, frames(:,:,:,f));
            pause(0.1);
            F = getframe(gcf);
            newFrames{f} =F;
        end
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
    task          = ndb.get(ndb.load(animal, 'task', 'indices', dayepoch), dayepoch);
    diotable      = ndb.load(animal, 'diotable', 'indices', dayepoch, 'asTidy', true);
    epochfilter   = diotable.day == dayepoch(1) & diotable.epoch == dayepoch(2);
    epochdiotable = diotable(epochfilter,:);
    if height(epochdiotable) == 0
        warning('Day %d Epoch %d: dio statescript file potentially unprocessed or no diotable! ... skipping', dayepoch(1), dayepoch(2));
        continue;
    end

    % Get video signal
    % ----------------
    if isrow(frames)  ||  iscolumn(frames);  error("Frame size error");  end
    videoSignal = register.well.quantile(frames, rects, 'ploton', Opt.ploton);
    if Opt.interactive
        input("quantile signal okay?",'s');
    end
    videoSignal = num2cell(videoSignal,1);
    videoTime = task.video.timestamps;
    names     = ["time", "well_" + (1:5)];
    videoSignal = table(videoTime, videoSignal{:}, ...
        'VariableNames', names);

    % Ready matrices to convolve at same sampling rate
    % ------------------------------------------------
    alignmentSamprate = 1500;
    [dioSignal, dioTime, videoSignal, videoTime] = ...
        register.equalize.returnMatrices(epochdiotable, videoSignal, alignmentSamprate);
    [offset, timeOffset, wellViolations, spread, wellsAligned] = register.computeDelay(dioTime, dioSignal, videoTime, videoSignal, alignmentSamprate,...
        'ploton',Opt.ploton);
    if Opt.interactive
        disp("Do these alignments appear alright?");
        keyboard
    end

    % Finally, let's apply changes to diotable
    % ----------------------------------------
    dio = ndb.load(animal, 'DIO', 'indices',  dayepoch);
    dio = ndb.unnest(dio, 'correction', ["indexOffset","timeOffset","timeOffsetDescription", "offsetDescription","wellViolations","spread","wellsAligned"], 'indices', dayepoch);
    diotable(epochfilter,:).time = diotable(epochfilter,:).time + timeOffset; % Apply correct to diotable
    %% ADD DATA!
    dio = ndb.addConst(dio, 'time', timeOffset, 'indices', dayepoch, 'addToExisting', true); % Apply correction to dio
    dio = ndb.addConst(dio, 'indexOffset', offset,     'indices', dayepoch, 'addToExisting', true);
    dio = ndb.addConst(dio, 'timeOffset',  timeOffset, 'indices', dayepoch, 'addToExisting', true);
    dio = ndb.addConst(dio, 'wellViolations',  wellViolations, 'indices', dayepoch, 'addToExisting', false);
    dio = ndb.addConst(dio, 'spread',  spread, 'indices', dayepoch, 'addToExisting', false);
    dio = ndb.addConst(dio, 'wellsAligned',  wellsAligned, 'indices', dayepoch, 'addToExisting', false);
    dio = ndb.addConst(dio, 'timeOffsetDescription', ...
        "Amount of time added to the dio time in order to acheive video+dio alignment",...
        'indices', dayepoch, 'addToExisting', false);
    dio = ndb.addConst(dio, 'offsetDescription',     ...
         sprintf("Total number of discrete shifts needed to shift video to match dio signal, sampled at %dhz",alignmentSamprate),...
        'indices', dayepoch, 'addToExisting', false);
    %  NEST THAT DATA INTO the .correction field
    dio = ndb.nest(dio, ["indexOffset","timeOffset","timeOffsetDescription", "offsetDescription","wellViolations","spread","wellsAligned"], 'correction', 'indices', dayepoch);
    if Opt.interactive
        keyboard
    end
    ndb.save(dio,      animal, 'DIO',      1);
    ndb.save(diotable, animal, 'diotable', 1);
    close all
end
