function varargout = eventsFromDioTable(animal, dayepoch, varargin)

ip = inputParser;
ip.addOptional('dataDir',[]);
ip.addParameter('flickerRemove_kws',struct(), @isstruct);
ip.parse(varargin{:});
opt = ip.Results;

if isempty(opt.dataDir)
    opt.dataDir = animaldef(animal);
    opt.dataDir = opt.dataDir{2};
end

if nargin < 2
    dayepoch = [];
end

% Obtain the nd-dimensional cell branch of all dio tables
D = ndBranch.load(animal, 'diotable',...
    'asTidy', true);

% For every group of day and epoch, we will find trial events and how dio
% events construct those.
events = table(); % 
[groups,uDays,uEpochs] = findgroups(D.day, D.epoch);
uDayEpoch = [uDays,uEpochs];
disp("uDays uEpochs")
disp(unique(uDayEpoch, 'rows'))
if ~isempty(dayepoch)
    m = min(size(dayepoch,2), 2);
end
keyboard
for g = unique(groups)'
    
    if ~isempty(dayepoch) && ~ismember(uDayEpoch(g,1:m), dayepoch(:,1:m), 'rows')
        continue
    end

    % Clean subtable for epoch
    % ------------------------
    % Get subtable and clean pulse bursts
    epochDio = D(groups ==  g, :);
    epochDio = dioLib.throwOutFlicker(epochDio, opt); % TODO do not remove flickers where the animal moves away from the well (a certain radius/path_distance) and comes back to poke
    dayEvents = table(); % trial event table

    % BOUNDARIES
    % ---------------------------------------------------------------------
    % Label points at which the cue pattern changes .. these describe TRIAL
    % ---------------------------------------------------------------------
    cue = dioLib.generateDioCurve(epochDio(epochDio.type=="cue",:));
    if isempty(cue)
        warning('\nNo cue  on  day %d epoch %d\n', uDays(g), uEpochs(g))
        continue
    end
    cue = dioLib.unstackBy(cue, 'curve', 'location',...
        'rmfield',["direction","num","region"]);
    cuetimes = cue.time;
    cueCount = sum(cueMatrix(cue),2);
    cueDiff  = [cueCount(1); ...
                diff(cueCount)];
    startBlock = cueDiff > 0 & cueCount == 2;
    stopBlock  = cueDiff < 0 & cueCount == 0;
    nStart = sum(startBlock);
    nStop  = sum(stopBlock);
    startBlock = find(startBlock);
    stopBlock  = find(stopBlock);
    if nStart > nStop
        startBlock(end) = [];
    elseif nStop > nStart
        stopBlock(end) = [];
    end
    nBlock = numel(startBlock);

    figure();
    ax = dioLib.plotDioCurve(epochDio,[],dayepoch, 'extraAxes', 2); set(gcf,'Position',get(0,'ScreenSize'))
    periods = [cuetimes(startBlock), cuetimes(stopBlock)];
    util.plot.windows(periods,...
        'colormap','matter',...
        'ylim',[0,2],...
        'ax',ax(end-1),...
        'varargin',{'FaceAlpha',0.50,'EdgeAlpha',0});
    arrayfun(@(x) text(ax(end-1),mean(periods(x,:)), 0.5, string(x), 'FontSize',20, 'Color','white'), 1:size(periods,1));
    title(ax(end-1), 'blocking');
    hold(ax(end-1),  'on')
    plot(ax(end-1),  cuetimes, cueCount, ':', 'LineWidth', 3, 'Color', 'white');
    title(ax(end),   'interblock');

    % Determine blockDio dayEvents
    dayEvents = table();
    singleBlock = [];
    for block = 1:nBlock
        blockstart = cuetimes(startBlock(block));
        blockstop  = cuetimes(stopBlock(block));
        assert( blockstart < blockstop );
        singleBlock = blockEvents(block, cueMatrix(cue), cuetimes,...
                            epochDio, blockstart, blockstop, singleBlock);
        dayEvents = [dayEvents; singleBlock];
        assert(all(ismember(["blockstart","blockend"], singleBlock.type)))
        assert(sum(ismember(["blockstart","blockend"], singleBlock.type))==2)
        pokes = find(singleBlock.type=="poke");
        if numel(pokes)>0
            periods = [[singleBlock(1,:).time; singleBlock(pokes(1:end-1),:).time+singleBlock(pokes(1:end-1),:).duration],[singleBlock(pokes(1:end),:).time+singleBlock(pokes(1:end),:).duration]];
            util.plot.windows(periods,...
                'colormap','dense',...
                'ylim',[0,1],...
                'ax',ax(end),...
                'varargin',{'FaceAlpha',0.50,'EdgeAlpha',0});
            text(mean(periods,'all'), 0.5, string(block), 'FontSize',20, 'Color','white');
        end
        prevSingleBlock = singleBlock;
    end
    drawnow;

    dayEvents.day   = repmat(epochDio.day(1),   height(dayEvents), 1);
    dayEvents.epoch = repmat(epochDio.epoch(1), height(dayEvents), 1);
    %if all(epochDio.day(1) == 36 &  epochDio.epoch(1) == 2)
    %    keyboard
    %end

    events  = [events; dayEvents];
end

assert(sum(events.type=="blockstart") == sum(events.type == "blockend"));

if nargout == 1
    varargout = events;
else
    ndb.save(events, animal, 'events', 1);
end

% ---------------------------------------------------------------------------
% --------------- HELPER FUNCTIONS ------------------------------------------
% ---------------------------------------------------------------------------
function events = blockEvents(block, cue, cuetimes, dio, trialstart, trialstop, lastBlock)
% Returns all events attached to this trial blocks dio

    dio = sortrows(dio,'time');
    blockEventCount = 0;
    blockDio = dio(dio.time >= trialstart & dio.time <= trialstop, :);
    events = exemplarEvent(0);

    %Compute path for this block
    home = blockDio(blockDio.type == "cue" & blockDio.region == "home",:).location;
    if ~isempty(home)
        path(1) = home(1);
    else
        path(1) = nan;
        warning('No home for block');
    end
    arena = blockDio(blockDio.type == "cue" & blockDio.region == "arena",:).location;
    if ~isempty(arena)
        path(2) = arena(1);
    else
        path(2) = nan;
        warning('No arena for block');
    end
    orderpath = path; % default to path unless otherwise detected


    % Iterate through pokes and assign 
    filt = blockDio.type == "poke";
    pokes = blockDio(filt,:);
    firstpokeyet = false;
    %pokes(pokes.state==1,:);
    homeCount = 0;
    arenaCount = 0;
    if numel(pokes) == 0
        startEvent = exemplarEvent;
        startEvent.block = block;
        startEvent.type = "blockstart";
        %if ~isempty(lastBlock)
        %    lastPokeEnd = max(lastBlock(lastBlock.type=="poke",:).time + lastBlock(lastBlock.type=="poke",:).duration);
        %else
        %    lastPokeEnd = -inf;
        %end
        startEvent.time = trialstart;
        startEvent.duration = max(blockDio.time) - min(blockDio.time);
        events = [events; startEvent];
    end
    for p = 1:height(pokes)
        if pokes(p,:).state == 0
            continue
        elseif pokes(p,:).state == 1
            if pokes(p,:).region == "arena"
                arenaCount = arenaCount + 1;
            elseif pokes(p,:).region == "home"
                homeCount = homeCount + 1;
            end
            event = exemplarEvent;
            event.block = block;
            event.subblock = min(homeCount, arenaCount)+1;
            event.traj = sum(events.type == "poke") + 1;
            event.type = "poke";
            event.time  = pokes(p,:).time;
            event.location = pokes(p,:).location;
            cuesActive = interp1(cuetimes, sum(cue,2), event.time, 'previous');
            if cuesActive == 2
                event.cuemem = "cue";
            else
                event.cuemem = "mem";
            end
            event.region = pokes(p,:).region;
            event.path = path;
            source = dio(dio.time < event.time & dio.type=="poke",:).location;
            if isempty(source)
                event.source = nan;
            else
                event.source = source(end);
            end
            endpoke = dio.time > event.time & ...
                      dio.location == event.location & ...
                      dio.region == event.region & ...
                      dio.state == 0 & ...
                      dio.type == "poke"; %search for next off state
            % Ensure path contains the first poke first
            if ~firstpokeyet
                if event.region == "arena"
                    orderpath = [path(2), path(1)];
                else
                    orderpath = [path(1), path(2)];
                end
                startEvent = exemplarEvent;
                startEvent.block = block;
                startEvent.type = "blockstart";
                if ~isempty(lastBlock)
                    lastPokeEnd = max(lastBlock(lastBlock.type=="poke",:).time + lastBlock(lastBlock.type=="poke",:).duration);
                else
                    lastPokeEnd = [];
                end
                if isempty(lastPokeEnd)
                    lastPokeEnd = -inf;
                end
                startEvent.time = max(trialstart, lastPokeEnd);
                startEvent.duration = max(blockDio.time) - min(blockDio.time);
                startEvent.path = path;
                events = [events; startEvent];
                blockEventCount = blockEventCount + 1;
                firstpokeyet = true;
            end
            event.orderpath = orderpath;
            if any(endpoke)
                endpoke = find(endpoke, 1, 'first');
                event.duration = dio(endpoke,:).time - event.time;
            else
                endpoke = nan;
            end
            events = [events; event];
            blockEventCount = blockEventCount + 1;
        end
    end

    % Iterate through reward and assign 
    homeCount = 0;
    arenaCount = 0;
    filt = blockDio.type == "reward";
    rewards = blockDio(filt,:);
    for p = 1:height(rewards)
        if rewards(p,:).state == 0
            continue
        elseif rewards(p,:).state == 1
            if rewards(p,:).region == "arena"
                arenaCount = arenaCount + 1;
            elseif rewards(p,:).region == "home"
                homeCount = homeCount + 1;
            end
            event = exemplarEvent;
            event.block = block;
            event.subblock = min(homeCount,arenaCount)+1;
            eventBlock = events(end-blockEventCount+1:end,:);
            event.time  = rewards(p,:).time;
            event.traj = sum(eventBlock.type == "poke" & eventBlock.time < event.time);
            event.type = "reward";
            event.location = rewards(p,:).location;
            cuesActive = interp1(cuetimes, sum(cue,2), event.time, 'previous');
            if cuesActive == 2
                event.cuemem = "cue";
            else
                event.cuemem = "mem";
            end
            event.region = rewards(p,:).region;
            event.path = path;
            event.orderpath = orderpath;
            source = dio(dio.time < event.time & dio.type=="poke",:).location;
            if isempty(source)
                event.source = nan;
            else
                event.source = source(end);
            end
            endreward = dio.time > event.time & dio.location == event.location & dio.region == event.region;
            if any(endreward)
                endreward = find(endreward, 1, 'first');
                event.duration = dio(endreward,:).time - event.time;
            else
                endreward = nan;
            end
            events = [events; event];
            blockEventCount = blockEventCount + 1;
        end
    end

    % Compute whether each poke was correct
    for p = find(events.type  == "poke")'
        if any(events.type == "reward" & events.traj == events.traj(p))
            events.correct(p) = true;
        else
            events.correct(p) = false;
        end
    end

    event = exemplarEvent;
    event.block = block;
    event.type = "blockend";
    event.time = max(blockDio.time);
    event.duration = max(blockDio.time) - min(blockDio.time);
    event.path = path;
    event.orderpath = orderpath;
    events = [events; event];
    blockEventCount = blockEventCount + 1;
    disp(events(end-blockEventCount+1:end,:));

function cm = cueMatrix(cueTable)
    names = string(cueTable.Properties.VariableNames(contains(cueTable.Properties.VariableNames, "location")))';
    split_names = split(names,"_");
    nums = str2double(split_names(:,3));
    cm = zeros(height(cueTable), 5);
    for num = nums'
        cm(:,num) = table2array(cueTable(:,names(nums==num)));
    end
function emptyevent = exemplarEvent(num)
    if nargin == 0
        num = 1;
    else
        num = 0;
    end
    type = string(nan);
    time = nan;
    block = nan;
    subblock = nan;
    traj = nan;
    region   = string(nan);
    cuemem =  string(nan);
    location = nan;
    duration = nan;
    correct = nan;
    path = [nan nan];
    orderpath = [nan nan];
    source = nan;
    %target  = nan;
    emptyevent = table(type, time, block, subblock, traj, region, cuemem, location, duration, correct, path, orderpath, source);
    if num == 0
        emptyevent(1,:) = [];
    end
