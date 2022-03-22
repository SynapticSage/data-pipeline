function varargout = quantileLocation(animal, dayepoch, varargin)
% returns logical or times where animal in in a certain quantile of x and y position

ip = inputParser;
ip.addParameter('x', []);
ip.addParameter('y', []);
ip.addParameter('output', 'index'); %  index | time
ip.addParameter('pos', 'rawpos'); %  index | time
ip.addParameter('returnSmoothedLikelihood', 0); %  works in output=index, returns the logical (converted to double) multiplied by smoothed likelihood
ip.parse(varargin{:})
Opt = ip.Results;

% Get position and likelihood
pos = ndb.load(animal, Opt.pos, 'indices', dayepoch);
posdata = cellfetch(pos,'data');
posdata = cat(1,posdata.values{:});
likdata = cellfetch(pos,'likelihood');
likdata = cat(1,likdata.values{:});

positions = true(size(posdata,1),1);
if ~isempty(Opt.x)
    x = posdata(:,2);
    positions = positions & ...
        x > quantile(x, Opt.x(1)) & x < quantile(x, Opt.x(2));
end
if ~isempty(Opt.y)
    y = posdata(:,3);
    positions = positions & ...
            y > quantile(y, Opt.y(1)) & y < quantile(y, Opt.y(2));
end

switch Opt.output
case 'index'
    varargout{1} = positions;
case 'time'
    varargout{2} = posdata(positions,1);
otherwise
    error("Bad output value")
end

varargout{1} = positions;
if strcmp(Opt.output,'index') && Opt.returnSmoothedLikelihood
    varargout{2} = smoothdata(prod(likdata,2), 'lowess', Opt.smoothedLikelihood);
end
