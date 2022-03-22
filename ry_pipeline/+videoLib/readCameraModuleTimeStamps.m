function times = readCameraModuleTimeStamps(filename)
% Version of the camera module time stamp reader that accounts
% for time offsets between files.

ip = inputParser;
ip.parse(varargin{:})
Opt = ip.Results;
