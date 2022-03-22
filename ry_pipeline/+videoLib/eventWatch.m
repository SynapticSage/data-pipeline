function framesets = eventWatch(animal, day, eventTimes, varargin)
% videoFrames = eventWatch(animal, eventTimes, varargin)
% ==================================================================
% Function for checking video of the animal fort track events
%
% Input
% -----
% animal : str, char
%   name of animal
%
% day : 1x1 or 1x2 vector
%   day or day .. 
%
% eventTimes : numeric vector
%   times to define events

ip = inputParser;
ip.addParameter('eventOff', []);     % If provided, these are the off cues for your event, and eventTimes is interpretted to be a beginning time
ip.addParameter('eventWindow', []);  % If provided, takes a window into your events. If given with eventOff and  eventTimes, then this field becomes like a before/after padding for eventTimes
ip.addParameter('timeSource', []); % Underlying source to same times in your [start_time stop_time] range : if empty, defaults to videoLib.frameDat(), the videos natural which has the videos natural sampling rate
ip.addParameter('stitch', false); % If stitch, return all frames sequentially/raveled, otherwise, return each group of frames in a cell
ip.parse(varargin{:})
Opt = ip.Results;

% Acquire the range of times
% --------------------------
eventRange = zeros(numel(eventTimes), 2);
eventOn = eventTimes;
if ~isempty(Opt.eventOff)
    eventTimes(:,1) = eventOn
    eventTimes(:,2) = Opt.eventOff
    if ~isempty(Opt.eventWindow)

        if numel(Opt.eventWindow) == 1
            eventTimes(:,1) = eventTimes(:,1) + abs(Opt.eventWindow);
            eventTimes(:,2) = eventTimes(:,2) - abs(Opt.eventWindow);
        elseif numel(Opt.eventWindow) == 2
            eventTimes(:,1) = eventTimes(:,1) + Opt.eventWindow(1);
            eventTimes(:,2) = eventTimes(:,2) - Opt.eventWindow(2);
        else
            error('eventWindow improper size')
        end
    end
else
    if ~isempty(Opt.eventWindow)
        if numel(Opt.eventWindow)  == 1
            eventTimes(:,1) = eventOn + abs(Opt.eventWindow);
            eventTimes(:,2) = eventOn - abs(Opt.eventWindow);
        elseif numel(Opt.eventWindow)  == 2
            eventTimes(:,1) = eventOn + Opt.eventWindow(1);
            eventTimes(:,2) = eventOn - Opt.eventWindow(2);
        else
            error("eventWindow improper size")
        end
    end
end

% Acquire the timescale to grab frames on
% ---------------------------------------
if ~isempty(Opt.timeSource)
    videoData = videoLib.frameDat(animal);
    t = videoData.videoTimes;
    videoSamplingRate = true;
else
    t = Opt.timeSource;
    videoSamplingRate = false;
end

% Find sets of matching times
% ---------------------------
timesets = cell(1, size(eventTimes,1));
indsets  = cell(1, size(eventTimes,1));
for s = 1:numel(timesets)
    inds = t >= eventTimes(:,1) & t <= eventTimes(:,2);
    timesets{s} = t(inds);
    indsets{s}  = inds;
end

% Grab frames for each of the events at the time scale given
% ----------------------------------------------------------
framesets = cell(1, size(eventTimes,1));
for s = 1:numel(timesets)
    if videoSamplingRate
        framesets{s} = videoLib.framesFromInds(animal, day, indsets{s});
    else
        framesets{s} = videoLib.framesFromTime(animal, day, timesets{s});
    end
end

if Opt.stitch
    framesets = cat(4,framesets{:});
end
