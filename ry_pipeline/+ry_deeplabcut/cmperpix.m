function cmperpix = cmperpix(rawDir, dataDir, animID, sessionNum, fileNameMask, varargin)
%This function generates cm/px for a video. If a first frame .jpg exists,
% it will use this frame. It is assumed that there is one (and only one) folder
%named '*time' in the current working directory that contains .dat files
%(result of extractTimeFiles.m).
%
%rawDir -- the directory where the raw dat folders are located
%fileNameMask -- the name of the file to be processed without extensions
%
% If unix, this script will convert raw .h264 into .mp4 and generate a
% first frame .jpeg. Conversion to .mp4 must be done manually for windows
% as of 08/16/16. If an .mp4 exists on windows, this script will convert to
% .jpeg as well.
%
% Ryan: LARGE changes
% ------------------
% - method no longer fails if you have mp4 but not h264 in your folder
% - better version of ginput (shows points being drawn during clicks)
% - if your scene in the video happens to be  dark, you can change the
%   video to another video matching the filename match
% - or you can select a different frame in the same video

ip = inputParser;
ip.addParameter('frameIndex', 1, @(x) x == round(x));
ip.addParameter('skipProc', true);
ip.addParameter('useAverageOfSessions', []);
ip.parse(varargin{:})
Opt = ip.Results;

if strcmp(rawDir(end),filesep)
    rawDir = rawDir(1:end-1);
end
currdir = pwd;
if ~strcmp(rawDir,currdir)
    cd(rawDir);
    cleanup = onCleanup(@() cd(currdir));
end

% Checkpoint location
cmperpixFile = fullfile(rawDir, sprintf('%scmperpix_%02d.txt', animID, sessionNum));

% Does a checkpoint already exist?
if ~isempty(dataDir) && Opt.skipProc
    
    % Check for cmperpix file in existing rawpos
    rawpos = ndb.load(animID, 'rawpos', 'indices', sessionNum);
    cmperpix = cellfetch(rawpos, 'cmperpixel');
    if ~isempty(cmperpix.index)
        cmperpix = cmperpix.values{1};
        if ~isempty(cmperpix)
            return;
        end

    end

    % For a cmperpix file
    if exist(cmperpixFile,'file')
        cmperpix = readlines(cmperpixFile);
        cmperpix = str2double(cmperpix);
        return;
    end
end
if ~isempty(Opt.useAverageOfSessions)
    task = ndb.load(animID, 'task',  'asNd', true);
    task = task(Opt.useAverageOfSessions,:);
    task = task(~arrayfun(@nd.isEmpty,task));
    video = nd.unnest(task,'video');
    cmperpix_video = nd.fieldGet(video, 'cmperpixel', 'squeeze', true, 'cat', 1);
    cmperpix = median(cmperpix_video);
    return;
else
    cmperpix = nan;
end

if isempty([dir(['*' fileNameMask '*.h264']); dir(['*' fileNameMask '*.mp4'])])
    error( ['*' fileNameMask '*.h264/mp4 not found!']);
end

cleanupFigures = onCleanup(@() close('all'));

%rawAllVids= dir([fileNameMask '*.h264']);
%rawVid= rawAllVids(1).name;
[epochTimes, fileDat] = getEpochs(1);
epochNames = cellfun(@(x) replace(x,'.trodesComments',''), {fileDat.file}, 'UniformOutput', false);
nEpochs = size(epochTimes,1);

%%%%%%%%%%%%%%%%%%%%
% Get/Make Video file
%%%%%%%%%%%%%%%%%%%%
videoNumber = 1;
video= [rawDir filesep '*' fileNameMask '*.mp4'];
if isstring(video)
    video = strjoin(video,"");
end
video = dir(video);
videoNames = cellfun(@(x) replace(x,'.mp4',''), {video.name},'UniformOutput',false);
nMatchingEpochs = sum(ismember(videoNames, epochNames));

known=[];
prevVideoNum = -1;
while isempty(known)
    % this block of code only executes in Linux if the .mp4 file does not
    % exist. It uses ffmeg locally to convert your .h264 file to a .mp4 file.
    if isempty(video(videoNumber)) && ispc
        disp('Sorry, this can only convert videos in Linux right now, convert your video using VLC to a .mp4 then try again!');
        return;
    elseif isempty(video(videoNumber)) && isunix
        cmd = ['ffmpeg -r 15 -i "' replace(video.name,'.mp4','') '.h264" -vcodec copy "' video.name '" '];
        unix(cmd);
    end

    %%%%%%%%%%%%%%%%%%%%
    % Show first frame, get distance and cm per pix
    %%%%%%%%%%%%%%%%%%%%
    if  prevVideoNum ~= videoNumber
        videoMeta = VideoReader(video(videoNumber).name);
        prevVideoNum = videoNumber;
    end
    vidImage  = replace(video(videoNumber).name, '.mp4', '.fig');

    disp('Reading video to get first frame image');
    tempFrame = figure('Name', fileNameMask, 'NumberTitle', 'off');
    clf;
    frame = read(videoMeta, Opt.frameIndex);
    % Adjust frame to be easy to see, regardless of lighting
    for i = 1:3
        frame(:,:,i) = adapthisteq(frame(:,:,i),'clipLimit',0.02,'Distribution','rayleigh');
    end
    imagesc(frame);
    fprintf('Frame %d found\n',Opt.frameIndex);
    
    keepLine = "No";
    action   = "Redraw";

    while keepLine ~= "Yes" && action  == "Redraw"
        [x, y]= ry_deeplabcut.ginputc(2,'ShowPoints',true,...
            'ConnectPoints',true,...
            'Color',[1 1 1],...
            'LineStyle','-');
        hold on
        line1 = plot(x,y,'g');
        keepLine = questdlg('Keep Drawn Line?','Confirm','Yes','No','Yes');
        keepLine = string(keepLine);
        switch char(keepLine)
            case 'No'
            delete(line1)
            action = questdlg('What do you want to do?','Recourse action',...
                'Redraw','ChangeVideo','ChangeFrame', 'Redraw');
            switch action
                case 'Redraw'
                case 'ChangeVideo'
                videoNumber = str2double(inputdlg(sprintf('Epoch number? (1..%d)',nMatchingEpochs)));
                case 'ChangeFrame'
                Opt.frameIndex = str2double(inputdlg(sprintf('While frame between 1 .. %d',floor(videoMeta.FrameRate*videoMeta.Duration))));
                while isempty(Opt.frameIndex) || ~isnumeric(Opt.frameIndex)
                    Opt.frameIndex = str2double(inputdlg(sprintf('While frame between 1 .. %d',floor(videoMeta.FrameRate*videoMeta.Duration))));
                end
            end
            case 'Yes'
            known = inputdlg('What is the known length in cm of the line you drew? (hit cancel to redo)');
            %close all
        end
    end
end

known = str2double(cell2mat(known));
cmperpix= known ./ sqrt((x(1)-x(2))^2 + (y(1)-y(2))^2);
text(range(x)/2+x(1),range(y)+y(1)+3,...
    sprintf('%2.2fcm --> %2.2f cmperpixel', known, cmperpix))
savefig(tempFrame, vidImage, 'compact');
fid = fopen(cmperpixFile, 'w');
if fid == -1
    error("File not openable")
end
fwrite(fid, num2str(cmperpix));
fclose(fid);
doclose = false;
if doclose
    close(tempFrame);
end
