function file = checkpointName(varargin)

if numel(varargin) == 1 && isstruct(varargin{1})
    varargin = util.struct2varargin(varargin{:});
end

name = DataHash(varargin);
name = string(name);
file  = sprintf('/tmp/frameCheckpoint_%s.mat',name);
