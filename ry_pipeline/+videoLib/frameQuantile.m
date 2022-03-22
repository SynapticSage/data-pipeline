function frame = frameQuantile(animal, dayepoch, q, varargin)
% Get a quantile frame of set of quantile frames from video

ip = inputParser;
ip.addParameter('timeSource', 'pos'); % pos, rawpos, video
ip.parse(varargin{:})
Opt = ip.Results;

switch Opt.timeSource
    case {'pos','rawpos'}
        time = ndBranch.load(animal, Opt.timeSource, 'indices', dayepoch);
        time = cellfetch(time,'data');
    case 'video'
        time = ndBranch.load(animal, 'task', 'indices', dayepoch);
        time = ndBranch.unnest(time, 'video');
        time = cellfetch(time, 'timestamps');
    otherwise
end
time = cat(1, time.values{:});
time = quantile(time, q);
frame = videoLib.framesFromTime(animal, dayepoch, time);
