function varargout = behavior(animID, dayepoch, beh, instructions, varargin)
%function varargout = behavior(animID, dayepoch, beh, instructions, varargin)
% Highly general behavior video or plot library
%
% fields in the struct and column numbers of those fields can be input for
% points or vectors to be plotted onto the field
%
% behahviors can be plotted with or without video, with or without
% caching of video
%
% if you want video, either set video option to true or simply
% pass in a nonempty videoOption struct.
%
% types include point, vector, polarElement, magnitudeElement, magnitudeLineElement

% ---------
% Optionals
% ---------
ip = inputParser;
% Video
ip.KeepUnmatched = true;
ip.addParameter('outputName', ''); %Every 1000 frames
ip.addParameter('outputCheckpoint', 1000); %Every 1000 frames
ip.addParameter('resize',[])
ip.addParameter('video',    true);
ip.addParameter('t0', 1);
ip.addParameter('persistent', false);
ip.addParameter('global',true);
ip.addParameter('videoOpt', struct('resize',0.25));
ip.parse(varargin{:})
Opt = ip.Results;
unmatched = ip.Unmatched;

if isempty(Opt.resize)
    Opt.resize = [964,1292] * Opt.videoOpt.resize;
end

Opt.videoOpt.global =  Opt.global;
Opt.videoOpt = util.struct2varargin(Opt.videoOpt);
%Opt.resize = Opt.resize(end:-1:1);

% -------------------
% Obtain video frames
% -------------------
dovideo = Opt.video || ~isempy(Opt.videoOpt);
if dovideo 
    [frames, vidM] = posLib.plot.video.get(animID, dayepoch, Opt.videoOpt{:});
end
resize = vidM.resize; % Any video frame resizing here

% -----------------------------------------------------
% If we have instruction objects, let's preprocess them
% -----------------------------------------------------
[instructions, iTable] = ...
    posLib.plot.util.preprocessInstructions(beh, instructions, ...
    'resize', resize, 'cmperpix', vidM.cmperpixel);

% ---------------------------------------------------------------
% Figure out how many axes that we're dealing with and initialize
% ---------------------------------------------------------------
uSingleStateAx = unique(iTable(contains(iTable.type,"singleStateAx"),:).axNum);
uStateAx = unique(iTable(contains(iTable.type,"gridState"),:).axNum);
uMagAx   = unique(iTable(contains(iTable.type,"magnitudeAx"),:).axNum);
uPolarAx = unique(iTable(contains(iTable.type,"polarAx"),:).axNum);
nMagAx   = numel(uMagAx);
nPolarAx = numel(uPolarAx);

axs = posLib.plot.initialize.axes(gcf,...
    'plots',[nMagAx, nPolarAx],...
    'plotPositions', {'bottom','left'},...
    'plotNames', ["stateAx","magnitudeAx","polarAx"]);

instructions = posLib.plot.placeAxes(instructions, axs);

% Initialize first frame of plot
% ------------------------------
if dovideo
    T = size(frames,4)-Opt.t0;
else
    T = posLib.plot.timelength(instructions);
end
t = Opt.t0;
if t>=0 && t<1
    t = quantile(1:T, t);
end
% Initialize the frame object
if dovideo
    frameIm = imagesc(axs(end), frames(:,:,:,t));
end

if nargout == 1 || ~isempty(Opt.outputName)
    outFrame = zeros([Opt.resize, 3, T],'uint8');
end

if ~isempty(Opt.outputName)
    M = matfile(Opt.outputName,'Writable', true);
elseif Opt.outputCheckpoint
    M = matfile(videoLib.checkpointName(Opt),'Writable', true);
end
if exist('M','var')
    if ~ismember('outFrame', fieldnames(M)) || ~isequal(size(M,'outFrame'),size(outFrame))
        M.outFrame = outFrame;
    end
end

% Initialize each instruction object
% ----------------------------------
for ii = 1:numel(instructions)
    instruction = instructions{ii};
    switch instruction.type
    case 'point'
    instruction.obj = posLib.plot.atom.point(instruction, t);
    case 'vector'
    instruction.obj = posLib.plot.atom.vector(instruction, t);
    case 'wellState'
    instruction.obj = posLib.plot.atom.wellState(instruction, t);
    case 'gridState'
    instruction.obj = posLib.plot.atom.gridState(instruction, t);
    case 'positionGridState'
    posLib.plot.atom.positionGridState(instruction, t);
    case 'polarAx'
    instruction.obj = posLib.plot.atom.polarAx(instruction, t);
    case 'magnitudeAx_bar'
    instruction.obj = posLib.plot.atom.magnitudeAx(instruction, t);
    case 'magnitudeAx_line'
    instruction.obj = posLib.plot.atom.magnitudeAx_line(instruction, t);
    end
    instructions{ii} = instruction;
end
title_ = title(sprintf('%d',t));
if nargout > 0 || ~isempty(Opt.outputName)
    this = getframe();
    outFrame(:,:,:,t) = imresize(this.cdata, 'OutputSize', Opt.resize);
end

% -----------------------------------------
% Iteratively updatee objects per each time
% -----------------------------------------
for t = progress(Opt.t0+1:T,'Title','Animate')

    if dovideo
        frameIm.CData = frames(:,:,:,t);
    end

    % Update for each instruction
    for ii = 1:numel(instructions)
        instruction = instructions{ii};
        switch instruction.type
        case 'point'
        posLib.plot.update.point(instruction, t);
        case 'vector'
        posLib.plot.update.vector(instruction, t);
        case 'wellState'
        posLib.plot.update.wellState(instruction, t);
        case 'positionGridState'
        posLib.plot.update.positionGridState(instruction, t);
        case 'gridState'
        posLib.plot.update.gridState(instruction, t);
        case 'polarAx'
        posLib.plot.update.polarAx(instruction, t);
        case 'magnitudeAx'
        posLib.plot.atom.magnitudeAx(instruction, t);
        case 'magnitudeAx_line'
        posLib.plot.atom.magnitudeAx_line(instruction, t);
        end
    end
    title_.String = sprintf('%d\ntime=%2.1f',t, beh.time(t));
    drawnow
    if nargout > 0 || ~isempty(Opt.outputName)
        this = getframe();
        outFrame(:,:,:,t) = imresize(this.cdata, 'OutputSize', Opt.resize);
    end
    if ~mod(t,Opt.outputCheckpoint)
        M.outFrame(:,:,:,(t-Opt.outputCheckpoint+1):t) =...
            outFrame(:,:,:,(t-Opt.outputCheckpoint+1):t);
    end
end

if ~isempty(Opt.outputName)
    [path,base,~] = fileparts(Opt.outputName);
    videoName = string(path) + filesep + string(base) + '.avi';
    disp("Creating " + videoName);
    videoLib.writeFrames2Video(videoName, M.outFrame, unmatched);
end
