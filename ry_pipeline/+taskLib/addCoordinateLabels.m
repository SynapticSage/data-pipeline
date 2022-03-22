function addCoordinateLabels(dayDir, dataDir, animID, index, varargin)
%createtaskstruct(dataDir,animID,index, coordprogram,Options)
%
% RY: Rewrote for my taskLibrary and made the coordinate program part easier
%
%This program creates the 'task' structure for each day's data. This
%structure contains information about the exposure number for each epoch
%and the linearization coordinates for each run session. If a task file
%already exists for one of the days in index, then that file is
%loaded and written to to prevent unwanted deletion of data.
%
%      --INPUTS--
%
%    dataDir - example 'data99/user/animaldatafolder/', a folder 
%                    containing processed matlab data for the animal
%       animID - animal specific prefix for each datafile
%    index - each row describes a run epoch - [day epoch]
%     coordprogram - a string with the name of the function that will
%                    provide the track segment location info. This
%                    program should take three inputs - 1) dataDir
%                    2) pos.data for an epoch, and 3) the epoch index [day epoch]
%                    The output of the program is a cell
%                    array, where each cell describes one trajectory on
%                    the track (do not count foreward and backward
%                    movement as 2 trajectories).  Inside each cell is
%                    a three dimentional M-by-2-by-N matrix.  The
%                    matrix gives the x and y coodinates for the M
%                    segment endpoints, across N timeframes.  N should
%                    equal the length of pos.data.  The
%                    segment end points should start with the position
%                    that the user wants to be 0 on the linear scale and 
%                    progress to the last segment.  All endpoints that
%                    are shared by two segments should only exist
%                    once per trajectory.  The function is called like
%                    this: coords = coordprogram(dataDir,pos{day}{epoch}.data,[day epoch])
%    ---OPTIONS----
%
%        overwrite - 1 to overwrite old task file (default), 0 to keep the same file
%                    and just change the epochs defined in index
%   lowercasethree - variable prefix. Default is ''.
%    combineepochs - value of 1 combines all the epochs for the day when
%                    calling coordprogram. Default 0;  


ip =inputParser;
ip.addParameter('coordprogram', 'getcoord_gmaze');
ip.addParameter('overwrite',     false)
ip.addParameter('combineepochs', true)
ip.addParameter('lowercasethree', '')
ip.addParameter('tryAverageOfSessions', []);
ip.parse(varargin{:});
Opt = ip.Results;
if iscellstr(Opt.coordprogram)
    Opt.coordprogram = string(Opt.coordprogram);
end
if isa(Opt.coordprogram, 'function_handle')
    coordProgramHandle = Opt.coordprogram;
elseif ischar(Opt.coordprogram) || isstring(Opt.coordprogram)
    eval(['coordProgramHandle = @',Opt.coordprogram,';']);
else
    error("Unimplemented. Please provide coordprogram for now");
end

currdir = pwd;
cd(dayDir);
cleanup = onCleanup(@() cd(dayDir));

% Determine session index
if isscalar(index)   %  in this case, user just gave us  the  session number and expects program to  figure  out  epochs
    [epochList, fileOffsets]  = getEpochs(1);
    index = [repmat(index, 1, size(epochList,1));  1:size(epochList,1)]';
else
    index = sortrows(index,1);
end

daytracker = 0;
task = [];
for i = 1:size(index,1)    

    day = index(i,1);
    epoch = index(i,2); 
    newday = 0;

    %  DETECT IF A NEW DAY: if  so, load data  and mark it as new
    if day ~= daytracker

       newday = 1;
       % Save if it's not the first day alreay and  we've changed days
       if daytracker ~= 0
           save( sprintf('%s/%stask%02d.mat', dataDir, animID, daytracker),  'task' )
       end

       % POS : load
       posfile = sprintf('%s/%spos%02d.mat',dataDir,  animID, day);
       pos =  load(posfile);
       pos  = pos.pos;
        
       % TASK  : load
       taskfile =  sprintf('%s/%stask%02d.mat',dataDir,  animID, day);
       if ~Opt.overwrite ||  ~exist(taskfile, 'file')
          %load the day's task data if it exists
          task =  load( taskfile );
          task = task.task;
       else
          task = [];
       end

       daytracker = day;
    end

    % Combine across epochs?
    if Opt.combineepochs && newday %we are using the same track coordinates for all epochs of the day

        posdata = [];
        poslikelihood = [];
        epochs_this_day = index((index(:,1) == day),2)';

        % Combine all of the epoch datas and run the coordinate program
        cmperpix = [];
        for epoch = epochs_this_day
            if numel(pos{day}) >= epoch && ~isempty(pos{day}{epoch}) && ~isempty(pos{day}{epoch}.data)
                posdata = [posdata;...
                pos{day}{epoch}.data];         
                poslikelihood = [poslikelihood;...
                pos{day}{epoch}.likelihood];         
                if isfield(pos{day}{epoch},'cmperpixel')
                    cmperpix = pos{day}{epoch}.cmperpixel;
                end
            end
        end
        %Obtain a video frame
        x = posdata(:,2);
        y = posdata(:,3);
        disp('Computing best time to sample  video  frame')
        smoothedLikelihood = smoothdata(prod(poslikelihood,2),'lowess', 4000);
        animalInMiddle = x > quantile(x,0.40) & x < quantile(x,0.60) & ...
                         y > quantile(y, 0.40) & y < quantile(y, 0.60);
        [~,goodRecordingTime] = max(smoothedLikelihood .* animalInMiddle);
        t = posdata(goodRecordingTime, 1);
        %x = posdata(goodRecordingTime:goodRecordingTime+1000, 2);
        %y = posdata(goodRecordingTime:goodRecordingTime+1000, 3);
        goodRecordingTime = t;
        tic
        disp('Acquiring video frame')
        checkpoint = videoLib.checkpointName(animID, day, goodRecordingTime);
        if exist(checkpoint,'file')
            load(checkpoint,'frame');
        else
            frame = videoLib.framesFromTime(animID, day, goodRecordingTime);
            save(checkpoint,'frame');
        end
        toc

        %Run the user-defined coordinate program
        disp('Obtaining coordinates in  video')
        [boundary, welllocs, arenaBoundary, homeBoundary, coords] = coordProgramHandle(frame, posdata, ...
            'animal', animID, ...
            'cmperpix', cmperpix, ...
            'tryAverageOfSessions', Opt.tryAverageOfSessions);

        % Copy  results to eeach epochs structure
        disp('Writing results')
        for epoch = epochs_this_day
            if numel(pos{day}) >= epoch && ~isempty(pos{day}{epoch})
                task{day}{epoch}.boundary = boundary;
                task{day}{epoch}.welllocs = welllocs;
                task{day}{epoch}.coords   = coords;
                task{day}{epoch}.arenaBoundary = arenaBoundary;
                task{day}{epoch}.homeBoundary  = homeBoundary;
                task{day}{epoch}.units  = 'px';
                if isfield(task{day}{epoch},'cmperpixel')
                    task{day}{epoch}.cmperpix  = pos{day}{epoch}.cmperpixel;
                end
            end
        end
    elseif ~Opt.combineepochs
        task{day}{epoch}.type = 'run';
        if ~isempty(Opt.coordprogram)
            error('not implemented')
        end
    end
end

% nest all of these properties under maze
task = ndBranch.nest(task, ["boundary","welllocs","homeBoundary", "arenaBoundary", "coords","units"], 'maze');

%save the final day's task file
taskfile = sprintf('%s/%stask%02d.mat', dataDir, animID, daytracker);
save(taskfile, 'task' )
