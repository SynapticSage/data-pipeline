function varargout = trajFromEventTable(animID, dayepoch, varargin)

ip = inputParser;
ip.KeepUnmatched;
ip.addParameter('trialStartEpsilon', 0.001); % start trials 10ms before withdrawing a nosepoke
ip.addParameter('ploton', true); % start trials 10ms before withdrawing a nosepoke
ip.parse(varargin{:})
Opt = ip.Results;
Params = ip.Unmatched;

if ~ndbFile.exist(animID, 'events')
    events = eventsFromDioTable(animID);
else
    events = ndb.load(animID, 'events', 'asTidy', true);
end

if nargin < 2
    dayepoch = [];
end

% Constants 
%averageRewardDur = nanmean(events(events.type=="reward",:).duration); 
averageRewardTable = unstack(events(events.type=="reward", ["day","epoch","location","duration"]), "duration", "location", 'AggregationFunction', @nanmean);
vars = setdiff(string(averageRewardTable.Properties.VariableNames), ["day","epoch"]);

% For results
trajs = exemplarTraj(0);

% Trackers across loop
prevpokedur = 0;
trialCount  = 0;
events = sortrows(events,["day","epoch","time"]);
[groups, uDays, uEpochs] = findgroups(events.day, events.epoch, events.block);
disp("Days epochs:")
disp(unique([uDays uEpochs], 'rows'))
uDayEpoch = [uDays,uEpochs];
m = min(size(dayepoch,2), 2);
prevPokeAndRewardTime = 0;
prevPokeAndDeengageTime = 0;
for g = unique(groups)'

    if ~isempty(dayepoch) &&...
       ~ismember(uDayEpoch(g,1:m), dayepoch(:,1:m), 'rows')
        continue
    end

    filt = groups == g;
    e = events(filt,:);
    pokes = e(e.type == "poke",:);
    t = repmat(exemplarTraj(),height(pokes),1);
    if height(pokes) == 0
        continue
    end
    rewards = e(e.type=="reward",:);
    [day,epoch] = deal(uDays(g),uEpochs(g));
    averageRewardDur = averageRewardTable(averageRewardTable.day  == day &...
                                          averageRewardTable.epoch == epoch, vars);
    averageRewardDur = table2array(averageRewardDur);


    % Compute the TRIAL ENDS
    % ----------------------
    % Trial ends are when decisions are rendered plus the reward time
    % ... if correct it's the actual reward time, if error, its the
    % poke plus the average latency until a reward cessates
    endtimes     = zeros(height(pokes),1);
    C            = logical(pokes.correct);
    trajselect   = arrayfun(@(traj) find(ismember(rewards.traj, traj),1,'last'), pokes(C,: ).traj);
    endtimes(C)  = rewards(trajselect,:).time + rewards(trajselect,:).duration;
    endtimes(~C) = pokes(~C,:).time + averageRewardDur(pokes(~C,:).location)';
    %stop = e(e.type == "blockend",:).time;
    t.stop = endtimes;

    %endpoketimes = zeros(height(pokes),1);
    endpoketimes = pokes.time + pokes.duration;
    t.endOfPoke  = [prevPokeAndDeengageTime; endpoketimes(1:end-1)]; % point at which animal de-engages poke and starts to run

    % Get the TRIAL STARTS
    % --------------------
    % Trial starts are either the block start
    % or the previous poke + poke duration if not blocklockout
    blockstart = e(e.type == "blockstart",:).time;
    start = max(prevPokeAndRewardTime, blockstart); % TODO blocklockout-conditional
    poketimes = pokes.time;
    pokedurs = pokes.duration;
    t.start = [start; endtimes(1:end-1)] + Opt.trialStartEpsilon;


    prevPokeAndRewardTime = endtimes(end);
    prevPokeAndDeengageTime = endpoketimes(end);

    % Easily obtained
    % ---------------
    t.day       = repmat(day, height(t),1);
    t.epoch       = repmat(epoch, height(t),1);
    t.correct   = pokes.correct;
    t.region    = pokes.region;
    t.cuemem    = pokes.cuemem;
    t.orderpath = pokes.orderpath;
    t.path      = pokes.path;
    t.source    = pokes.source;
    t.target    = pokes.location;
    t.block     = pokes.block;
    t.subblock  = pokes.subblock;
    t.traj      = pokes.traj;
    t.index     = (trialCount + (1:height(t)))';
    trialCount  = t.index(end);

    try
        trajs = [trajs; t];
    catch ME
        setdiff(string(trajs.Properties.VariableNames),string(t.Properties.VariableNames))
        setdiff(string(t.Properties.VariableNames),string(trajs.Properties.VariableNames))
        keyboard
    end

   
end

if Opt.ploton
    clf
    diotable = ndb.load(animID, 'diotable',...
        'indices', dayepoch,'asTidy',true);
    pos = ndb.load(animID, 'pos',...
        'indices', dayepoch,'get',true);
    pos = cellfetch(pos,'data');
    pos = cat(1,pos.values{:});
    ax = dioLib.plotDioCurve(diotable,[],dayepoch, 'extraAxes', 1);
    set(gcf,'Position',get(0,'ScreenSize'))
    plot(ax(end), pos(:,1), pos(:,end),':','color',[1 1 1 0.25],'linewidth',1);
    hold on;
    groups = findgroups(trajs.day,trajs.epoch,trajs.block);
    for g = unique(groups)'
        T = trajs(groups == g,:);
        periods = [T.start, T.stop];
        util.plot.windows(periods,...
            'colormap','matter',...
            'ax',ax(end),...
            'varargin',{'FaceAlpha',0.50,'EdgeAlpha',0.5, 'LineWidth',0.02});
    end
    periods = [trajs.start, trajs.stop];
    arrayfun(@(x) text(ax(end-2),mean(periods(x,:)), 0.5, string(x), 'FontSize',14, 'Color','black'), 1:size(periods,1));
    xlim([min(trajs.stop),...
          max(trajs.start)])
    plot(ax(end), pos(:,1), smoothdata(pos(:,end)),':','color',[1 1 1 1],'linewidth',1.2);
    ylim(ax(end),[0, quantile(pos(:,end),0.99)])
end

% Save the data
disp("Writing traj...");
ndb.save(trajs, animID, 'traj', 1)
disp("Done");

function emptyevent = exemplarTraj(num)
    if nargin == 0
        num = 1;
    else
        num = 0;
    end

    day     = nan;
    epoch     = nan;
    index     = nan;
    trial     = nan;
    start     = nan;
    stop      = nan;
    endOfPoke = nan;
    cuemem    = nan;
    correct   = nan;
    block     = nan;  % number of the trial block
    subblock  = nan; % home-arena pair within the block
    traj      = nan; % trajectory number within the block
    region    = string(nan);
    path      = [nan nan];
    orderpath = [nan nan];
    source    = nan;
    target    = nan;
    emptyevent = table(day, epoch, index, start, stop, endOfPoke, cuemem, correct, block, subblock, traj, region, path, orderpath, source, target);

    if num == 0
        emptyevent(1,:) = [];
    end

