function varargout = frameread(video, varargin)
% Where video can be the video file or the video reader object

%--Optional Arguments-----
ip = inputParser;
% ------------------------
ip.addParameter('videotimeStamps',[]);
ip.addParameter('pos',[]);
%--------------------------
ip.addParameter('times',[]);  % Times to match
ip.addParameter('indices',[]);% Indices to pull
%--------------------------
ip.addParameter('crop', []);
ip.addParameter('resize', []); % imresize frames
ip.addParameter('matfile',[]) % if given, outputs to matfile instead of 
ip.addParameter('fieldname','frames'); % field name for frames
ip.addParameter('format', {"uint8"}, @(x) iscell(x) || isstring(x) || ischar(x))
ip.parse(varargin{:});
opt = ip.Results;
if isstring(opt.format) || ischar(opt.format)
    opt.format = {opt.format};
end
if istable(opt.indices)
    opt.indices = table2array(opt.indices);
end

if isa(video,'VideoReader')
    % VideoReader was opened outside this function
elseif isstring(video) || ischar(video)
    video = VideoReader(video);
    destructor = onCleanup(@() video.close());
else
    error("video is improper type");
end

if isempty(opt.times) && isempty(opt.indices) % Request all frames
    opt.indices =  1:numel(postimes);
elseif isempty(opt.indices) % TIME LOOKUP MODE
    times  = getpostimes(opt);
    inds = 1:numel(times);
    opt.indices = interp1(times,inds,opt.times);
end

if numel(opt.indices) == 1
    tmp = video.read(opt.indices);
    tmp = postprocess(tmp, opt);
    varargout{1} = tmp;
    if nargout == 2
        varargout{2} = opt.indices;
    end
    return
end

% Use computed indices to grab all contiguous sections of video frame
[uIndices, ~, ic] = unique(opt.indices);
dIndices = [0; diff(uIndices)];
islands = cumsum(dIndices);
uIslands = unique(islands);
uIslands = uIslands(:);

% Get all contiguous chunks of frames
if ~isempty(opt.matfile)
    M = matfile(opt.matfile, 'Writable', true);
    if ~isfield(M, opt.fieldname)  || ~isequal(size(M.frames), [video.Height, video.Width, 3, numel(uIndices)])
        M.(opt.fieldname) = zeros(ceil(video.Height*opt.resize), ceil(video.Width*opt.resize), 3, numel(uIndices), opt.format{:});
    end
else
    frames = zeros(video.Height, video.Width, 3, numel(uIndices), opt.format{:});
end
for i = progress(uIslands', 'Title', 'Grabbing frames')
    filter = uIslands == i;
    minI = find(filter, 1, 'first');
    maxI = find(filter, 1, 'last');
    tmp = video.read([minI maxI]);
    tmp = postprocess(tmp, opt);
    if ~isempty(opt.matfile)
        M.(opt.fieldname)(:,:, :, minI:maxI) = tmp;
    else
        frames(:,:, :, filter) = tmp;
    end
end
if ~isempty(opt.matfile)
    M.ic = ic;
    clear M;
end

if nargout == 1
    % Return frames requested, expanded into non-unique form
    if ~isempty(opt.matfile)
        error('Nargout must be 0 when asking for a matfile');
    else
        varargout{1} = frames(:,:,ic);
    end
elseif nargout == 2
    % Return unique frames and index to expand into frames requested
    if ~isempty(opt.matfile)
        error('Nargout must be 0 when asking for a matfile');
    else
        varargout{1} = frames;
        varargout{2} = ic;
    end
elseif nargout ==0
    % This is fine
else
    error("Improper number of outputs")
end

% ----------------------------------------------------------------------
    function timestamps = getpostimes(opt)

    % Get time
    if ~isempty(opt.videoTimeStamps)
        if ischar(opt.videoTimeStamps) || isstring(opt.videoTimeStamps) && exist(opt.videoTimeStamps,'file')
            timestamps = readCameraModuleTimeStamps(opt.videoTimeStamps);
        elseif isnumeric(opt.videoTimeStamps)
            % User passed stamps directly
            timestamps = opt.videoTimeStamps;
        else
            error('Unrecognized type for videoTimeStamps')
        end
    elseif ~isempty(opt.pos)
        if isstruct(opt.pos)
            timestamps = opt.pos.data(:,1);
        else
            error('Unreognized type for  pos. Must be struct.')
        end
    end

    function frame=postprocess(frame, opt)

        if ~isempty(opt.crop)
            frame = imcrop(frame, opt.crop);
        end
        if ~isempty(opt.resize)
            frame = imresize(frame,opt.resize);
        end

