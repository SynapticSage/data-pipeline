function initializeTaskStruct(dayDir, dataDir, animID, sessionNum,  varargin)
% Initializes the task file from the comments file (as Trodes intended in its
% design)
% 
%This code assumes all of the labels, e.g. sleep/run are  already in your
%trodes comments files, as the makers of Trodes intended. We allow the NQ
%function to scaffold the initial task structure and the jadhavlab function
%createtaskstruct to fill in missing details about the shape of the track.

ip = inputParser;
ip.addParameter('addVideoDescription', true,...
    @(x) islogical(x) || x == 1 || x == 0);
ip.addParameter('videoToDataDir', 'link',...
    @(x) ischar(x)  || istring(x));
ip.addParameter('events2labels', true, ...
    @(x) islogical(x) || x == 1 || x == 0);
ip.addParameter('overwrite', false);
ip.parse(varargin{:})
Opt = ip.Results;

currdir = pwd;
cleaupFunction = onCleanup(@() cd(currdir));

cd(dayDir);
taskFile = sprintf('%s/%stask%02d.mat', dataDir, animID, sessionNum);
if Opt.overwrite || ~exist(taskFile, 'file')
    createNQTaskFile(dataDir, animID, sessionNum);
end

% Add pararmeters relevant for videos
[~, commentFiles] = getEpochs(1);
load(taskFile,'task');

% Set comment events as lavels?
% =============================
if Opt.events2labels
    indices = ndBranch.indicesMatrixForm(task);
    for index = indices'
        t = ndBranch.get(task, index);
        if ~isfield(t,'events')
            continue
        end
        for event = t.events(:)'
            t.(event.name) = event.description;
        end
        t = rmfield(t, 'events');
        task = ndBranch.set(task, index,  t);
    end
end

% Add video info
% ==============
if Opt.addVideoDescription
    
    if any(strcmp(Opt.videoToDataDir, { 'copy', 'link', 'move' })) && ...
            ~exist(fullfile(dataDir, 'videos'), 'dir')
        mkdir(fullfile(dataDir,'videos'))
    end

    rawpos = ndBranch.load(animID, 'rawpos', 'indices', sessionNum);
    indices = ndBranch.indicesMatrixForm(task);
    cnt = 0;
    for index = indices'
        cnt = cnt + 1;

        t = ndBranch.get(task, index);

        t.video.raw.offset = commentFiles(cnt).offset;
        tsFile = replace(commentFiles(cnt).file, 'trodesComments', 'videoTimeStamps');
        t.video.raw.timestampFile = tsFile;
        t.video.timestamps = readCameraModuleTimeStamps(tsFile) + t.video.raw.offset;
        videoFile = replace(commentFiles(cnt).file, 'trodesComments', 'mp4');
        t.video.raw.videoFile = videoFile;

        videoFile_newname = sprintf('%svideo%02d-%02d.mp4', animID, index(1), index(2));
        tsFile_newname    = sprintf('%stimestamp%02d-%02d.dat', animID, index(1), index(2));
        videoFile = string(videoFile);
        tsFile    = string(tsFile);
        videoFile_newname = string(videoFile_newname);
        tsFile_newname    = string(tsFile_newname);

        % Place video-related files into dataDir?
        switch char(Opt.videoToDataDir)
            case 'copy'
                evalstrs = "!cp -f $(pwd)/" + [videoFile; tsFile] + " "  + fullfile(dataDir,'videos',[videoFile_newname; tsFile_newname]);
            case 'link'
                evalstrs = "!ln -sf $(pwd)/" + [videoFile; tsFile] + " "  + fullfile(dataDir,'videos',[videoFile_newname; tsFile_newname]);
            case 'move'
                evalstrs(1) = "!cp -sf $(pwd)/" + tsFile    + " " + fullfile(dataDir,'videos',tsFile_newname);
                evalstrs(2) = "!mv -sf $(pwd)/" + videoFile + " " + fullfile(dataDir,'videos',videoFile_newname);
            otherewise
                evalstrs = [];
        end
        for evalstr =  evalstrs'
            eval(evalstr);
        end
        
        % Since cmperpix can be useful for working with
        % video, we add that too here
        t.video.units = 'px';
        if ndBranch.exists(rawpos, index)
            t.video.cmperpixel = rawpos{index(1)}{index(2)}.cmperpixel;
        end

        task = ndBranch.set(task, index, t);
    end
end

save(sprintf('%s/%stask%02d.mat', dataDir, animID, sessionNum),'task');


