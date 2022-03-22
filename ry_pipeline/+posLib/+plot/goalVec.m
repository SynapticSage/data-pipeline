function plotGpos(gpos)
% Goal pos : plots various aspects about goal pos for
% illustrative purposes and debugging.

ip = inputParser;
% OPTIONS FOR DISPLAY
ip.addParameter('tail', 0); % Tail of points to plot
ip.addParameter('displayGrid', true); % Show the grid of goal regions
% FOR LOOP ANIMATION OPTIONS
ip.addParameter('pause', 1/60); % Pause in the for loop
% VIDEO FRAME OPTS
ip.addParameter('fullvideo', false); % Create a video of all frames?
ip.addParameter('frames', []); % Option to pass in frames
ip.addParameter('preFetchFrames', false); % Prefetch frames?
ip.addParameter('endframe', -1);
% SUBJECTS OF PLOT
ip.parse(varargin{:})
Opt = ip.Results;

%Final  frame plot
if Opt.endframe == -1
    Opt.endframe = size(R,1);
else
    Opt.endframe = min(size(R,1),Opt.endframe);
end

for t = progress(1:Opt.endframe)

