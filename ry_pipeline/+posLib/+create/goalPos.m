function goalPos(animal, dayepoch, varargin)
% Greate the egocentric pos data

ip = inputParser;
ip.addParameter('ploton', true);
ip.addParameter('lowVeloctiyToHeadDir', true);
ip.addParameter('useHeadDir', false);
ip.parse(varargin{:})
Opt = ip.Results;

pos  = ndb.load(animal,  'pos', 'indices',  dayepoch);
traj = ndb.load(animal, 'traj', 'indices',  dayepoch,...
    'asTidy', true);
events = ndb.load(animal, 'events', 'indices',  dayepoch,...
    'asTidy', true);
task = ndb.load(animal, 'task', 'indices',  dayepoch);
indices = intersect(...
    ndb.indicesMatrixForm(pos),...
    ndb.indicesMatrixForm(task), 'rows');

if ~isempty(dayepoch)
    m = min(size(indices,2), size(dayepoch,2));
    filt =  ismember(indices(:,1:m),dayepoch(:,1:m),'rows');
    indices = indices(filt,:);
end

description = [...
            "gridTable : table of grid positions and their properties - some measurements are computed against this",...
            "stopWell : well an animal ends a trajectory on",...
            "startWell : well an animal starts a trajectory on", ...
            "goalVec : goal vectors to each well in complex coordinates",...
            "velVec : heading vector defined by velocity", ...
            "headVec : dheading-like vector defined by head direction", ...
            "egoVec : the egocentric vector using velocity heading in complex coordinates",...
            "angle (egoAngle) : the egocentric angle",...
            "euclidianDistance : the euclidean distance of the animal to each well",...
            "headEgoAngle : the head-direction based egocentric angle",...
            "currentPathLength : path length to the current goal",...
            "pathX : x of animal on path",...
            "pathY : y on animal on path",...
            "trialTime : start/stop times of a current path at every time point",...
            "currentAngle : current egocentric angle",...
            "currentEucDist : current euclidean distance",...
            "currentGoalVec : current vector to the current goal",...
            "currentEgoVec : current egocentric vector to the goal, using velocity heading",...
            "currentHeadEgoAngle : current egocentric vector to the goal, using head direction as heading",...
            "currentGoalVec : current vector to goal",...
            "currentHeadEgoAngle : current head direction based ego vec",...
            "cuemem : the cue-memory state",...
            "region : the region that the animal is currently inside"];
description = join(description, newline);

% So now  that we have the indices common to both,
% let's iterate over and enumerate
egopos = {};
for index = progress(indices','Title','Create egocentric pos')

    day   = index(1);
    epoch = index(2);
    tsk = ndb.get(task, index);
    p  =  ndb.get(pos, index);
    t  =  traj(traj.day == day,:);
    event  =  events(events.day == day,:);
    if ismember('epoch',t.Properties.VariableNames)
        t  = t(t.epoch == epoch, :);
        event  =  events(events.day == day,:);
    end

    if  height(t)  == 0 && tsk.task ~= "forage"
        warning('Day %d Epoch %d is empty', day, epoch);
        continue
    end

    % first, the easy part
    e = struct();
    e.postime = p.data(:,1);
    e.pos     = p.data(:,2:3);
    e.headdir = p.data(:,4);
    e.speed   = p.data(:,5);
    % TODO outside this function, angular correlation between
    % animals head direction and velocity

    % let's  create a grid
    gridTable = posLib.create.positionGrid(ndb.get(task,index));
    e.gridTable = table2struct(gridTable);

    % Get list of current wells animal moving toward vs time
    posTime = p.data(:,1);
    if tsk.task ~= "forage"
        t(isnan(t.stop),:) = []; % Drop any nan entries
        startWell = t.source;
        startTime = t.start;
        stopWell  = t.target;
        stopTime  = t.stop;
        startWell   = interp1(startTime, single(startWell), posTime, 'previous');
        stopWell    = interp1(stopTime,  single(stopWell),  posTime, 'next');
        e.startWell = startWell; % CHANGE
        e.stopWell  = stopWell;  % CHANGE

        % Set all stopWell and startWell times to nan outside of blocks
        insideBlock = isIncluded(posTime, [t.start, t.stop]);
        e.startWell = e.startWell .* insideBlock;
        e.stopWell  = e.stopWell  .* insideBlock;
        e.startWell = fillmissing(e.startWell, 'constant', -1);
        e.stopWell  = fillmissing(e.stopWell,  'constant', -1);
        e.startWell(e.startWell == 0) = -1;
        e.stopWell(e.stopWell   == 0) = -1;
    end

    %%  EGOCENTRIC ANGLES
    % time along rows and well property along columns
    % Obtain the animals heading vector
    %velVec = p.data(:,4) + i*p.data(:,5); % from animal along rows
    wellVec = transpose(gridTable.center_x + 1i*gridTable.center_y); % whatever from the maze, send it's direction along columns
    time = p.data(:,1);
    x    = p.data(:,2);
    y    = p.data(:,3);
    dt   = [0; diff(time)];

    % Turn animal location into a complex vector
    animVec  =  x + 1i*y;

    % Get the complex of head direction
    if ~isfield(p,'direction_complex')
        headVec  =  exp(1i*(e.headdir+pi));
    else
        headVec  =  p.direction_complex;
    end

    % Compute velocity complex vector from diff of complex animal position
    velVec   = [0, 0; diff([x, y])]./dt;

    % Filter out low velocity .. zero or set to head dir vector!
    vFilt = sqrt(sum(abs(velVec).^2))<1;
    if Opt.lowVeloctiyToHeadDir
        velVec(vFilt,:) = [real(headVec(vFilt)), imag(headVec(vFilt))];
    else
        velVec(vFilt,:) = 0;
    end
    % Smooth velocity
    velVec_smooth   = smoothdata(velVec);
    velVec_smooth = velVec_smooth(:,1) + 1i*velVec_smooth(:,2);
    velVec        = velVec(:,1) + 1i*velVec(:,2);
    angleDiff = [0; diff(angle(velVec))];
    smoothAngleDiff = [0; diff(angle(velVec_smooth))];
    velVec(angleDiff > pi/2) = 0;
    velVec_smooth(abs(velVec) < 3 & smoothAngleDiff > pi/2) = nan;

    if tsk.task ~= "forage"
        % Compute goal vector as the difference between each well posoition and animal position at all times
        goalVec  = wellVec - animVec; % broadcasts
        gFilt = abs(goalVec) < 0.5; % any times animal less than 1cm from well
        goalVec(gFilt) = 0 ; % Zero any measurements wehre animal too close to reference point
        headEgoAngle = mod(angle(goalVec)-angle(headVec)+pi,2*pi)-pi;
        egoAngle     = mod(angle(goalVec)-angle(velVec_smooth)+pi,2*pi)-pi;
        egoEuc   = abs(goalVec);

        %e.vec   = egoVec;
        e.goalVec = goalVec;
        e.velVec  = velVec_smooth;
        e.headVec = headVec;
        e.egoVec            = egoEuc .* exp(1i * egoAngle);
        e.angle             = egoAngle;
        e.headEgoAngle             = headEgoAngle;
        e.euclidianDistance = egoEuc; %CHANGE

        % Times where animals nose in a poke (we do not want angles in this time
        % nor do we want to integrate velocity for distanc traveled if nose in a
        % poke. points wiggle even when animal is still, generating significant
        % path-integration drift)
        pokeEngagement = event(event.type == "poke",:).time;
        pokeEngagement = [pokeEngagement, pokeEngagement + event(event.type == "poke",:).duration];
        pokeEngagement = isIncluded(e.postime, pokeEngagement);

        % COMPUTE PATH arc lengths
        vx = real(velVec);
        vy = imag(velVec);
        V = sqrt(vx.^2 + vy.^2);
        V = fillmissing(V, 'previous');
        pathLength = nan(size(x));
        maxPathLength = nan(size(x));
        pathX = cell(1,height(t));
        pathY = cell(1,height(t));
        trialTimes = zeros(height(t),2);
        for row = 1:height(t)
            start =t.start(row);
            stop = t.stop(row);
            filt = time >= start &  time < stop & ~pokeEngagement;
            %pathLength(filt) = cumsum(sqrt(1 + V(filt).^2) .* dt(filt));  %\int_a^b sqrt( 1 + dx/dt ) * dt
            P = cumsum(V(filt) .* dt(filt));  %\int_a^b sqrt( 1 + dx/dt ) * dt
            P = max(P) - P;
            pathLength(filt) = P;
            maxPathLength(filt) = repmat(max(P), size(P));
            pathX{row} = x(filt);
            pathY{row} = y(filt);
            trialTimes(row,1) = start;
            trialTimes(row,2) = stop;
        end
        e.currentPathLength = pathLength;
        e.currentPathLengthMax = maxPathLength;
        e.pathX = pathX;
        e.pathY = pathY;
        e.trialTimes = trialTimes;

        e.currentAngle   = nan(size(posTime));
        e.currentEucDist = nan(size(posTime));
        e.currentGoalVec = nan(size(posTime));
        e.currentEgoVec  = nan(size(posTime));
        e.currentHeadEgoAngle = nan(size(posTime));
        for ii = 1:numel(posTime)
            if e.stopWell(ii) ~= -1 && ~pokeEngagement(ii)
                e.currentEgoVec(ii)       = e.egoVec(ii,            e.stopWell(ii));
                e.currentAngle(ii)        = e.angle(ii,             e.stopWell(ii));
                e.currentHeadEgoAngle(ii) = e.headEgoAngle(ii,      e.stopWell(ii));
                e.currentEucDist(ii)      = e.euclidianDistance(ii, e.stopWell(ii));
                e.currentGoalVec(ii)      = e.goalVec(ii,           e.stopWell(ii));
            end
        end

        % Add cuememory state
        cuemem = t.cuemem;
        [~,~,e.cuemem] = unique(cuemem);
        e.cuemem = interp1(startTime, e.cuemem, posTime, 'previous');
        e.cuemem = e.cuemem .* insideBlock;
        e.cuemem = e.cuemem - 1;
        e.cuemem = fillmissing(e.cuemem, 'constant', -1);
        % Correct versus error state
        correct   = t.correct;
        correct     = interp1(stopTime,  single(correct),   posTime, 'next');
        correct = (correct+1) .* insideBlock;
        correct = correct - 1;
        e.correct = fillmissing(correct, 'constant', -1);
        % Region
        [~,~,region]    = unique(t.region);
        region     = interp1(stopTime,  single(region),   posTime, 'next');
        region = (region) .* insideBlock;
        region = region - 1;
        e.region = fillmissing(region, 'constant', -1);

        for field = string(fieldnames(e))'
            if isa(e.(field),'double')
                e.(field) = single(e.(field));
            end
        end

        e.poke = posLib.poke.getMatrix(animal, dayepoch, e.postime, "input", "poke");
        e.milk = posLib.poke.getMatrix(animal, dayepoch, e.postime, "output", "reward");
    end

    e.description = description;
    egopos = ndb.set(egopos, index, e);

    if Opt.ploton && tsk.task ~= "forage"
        tic
        fig(sprintf('GOALPOS Day %d Epoch %d',day,epoch))
        clf
        diotable = ndb.load(animal,'diotable',...
            'indices', [day epoch],...
            'asTidy', true);
        ax = dioLib.plotDioCurve(diotable,[],dayepoch, 'extraAxes', 3, 'removeFlicker', false); 
        set(gcf,'Position',get(0,'ScreenSize'))
        %A(A>quantile(A,0.99)) = quantile(A,0.99);
        %A = (A-min(A))./(max(A)-min(A));
        %A = A - range(A)/2;
        V = abs(velVec);
        V(V>quantile(V,0.99)) = quantile(V,0.99);
        V = (V-min(V))./(max(V)-min(V));
        %A = [e.currentAngle, angle(e.currentGoalVec), angle(velVec)];
        A = [e.currentAngle];
        A = (A-nanmean(A,1))./diff(quantile(A,[0.001,0.99],1));
        %A(V<quantile(V,0.7),:) = nan;
        colors = cmocean('haline',5);
        cla(ax(end))
        plot(ax(end),e.postime, A(:,1), 'Color', colors(2,:))
        ylabel(ax(end), "Goal Angle");
        plot(ax(end-1),e.postime, V+0.5, '-.', 'linewidth', 1.5, 'color', 0.5*ones(1,3));
        ylabel(ax(end-1), "Normalized Velocity");
        plot(ax(end-2),e.postime, e.currentPathLength, '-.', 'linewidth', 1.5, 'color', 0.5*ones(1,3));
        %hpathlength to the current goalold(ax(end-2),"on");
        plot(ax(end-2),e.postime, e.currentEucDist, ':', 'linewidth', 1.5, 'color', 0.75*ones(1,3));
        ylabel(ax(end-1), "Current Euc\nDist");
        set(ax,'xtick',[]);
        %ylim(ax(end),[-0.5, 1.5]);
        if ~exist(fullfile(ndbFile.folder(animal), "epoch_describe"), "dir")
            mkdir(fullfile(ndbFile.folder(animal), "epoch_describe"))
        end
        savefile = fullfile(ndbFile.folder(animal), "epoch_describe", sprintf("behavior_and_dio_%d_%d",day,epoch));
        savefig(savefile + ".fig")
        saveas(gcf,savefile + ".png")
        toc
    end

end


ndb.save(egopos, animal, 'behavior', 1);

% ---------------------------------------
% Make backwards compatible with old name
% ---------------------------------------
folder  = ndbFile.folder(animal, "egocentric");
files   = ndbFile.files(animal + "behavior", dayepoch, folder);
currdir = pwd;
des     = onCleanup(@() cd(currdir));
cd(folder);
new     = files.name;
old     = replace(new, 'behavior', 'egocentric');
system(['ln -sf ' new ' ./' old]);
