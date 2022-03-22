                    function generateGlobalRipples(animalprefix, varargin)

% Global ripple file from Wenbo, modified by ryan;*

days         = 1;
minstd       = 3;
minrip       = 1;
minenergy    = 0;
velfilter    = 4; %velthresh
matcheegtime = 0;
brainarea    = 'CA1';
taskfilter = 'string($type) == "run"';
rippletype = 'ripples';
name = 'rippletime';
varargin = optlistassign(who, varargin{:});
animalToPath(animalprefix);

%%
ndb.load(animalprefix, 'tetinfo');
ndb.load(animalprefix, 'task');
matchingInds = evaluatefilter(task, taskfilter);
nonemptyTet = ndb.indicesMatrixForm(tetinfo);
rippleInds  = ndbFile.indicesMatrixForm(animalprefix, rippletype);
matchingInds = intersect(matchingInds, nonemptyTet(:,1:2), 'rows');
inds = ismember(matchingInds(:, 1), rippleInds(:,1));
matchingInds = matchingInds(inds,:);
task = ndb.toNd(task);

%%
clear index;
dprev = 0;
for de = progress(matchingInds','Title','Generating global ripple')
    
    d = de(1);
    e = de(2);

    if d ~= dprev
        clear globalripple
        ripples = ndb.load(animalprefix, rippletype, 'inds', d);
        pos = ndb.load(animalprefix, 'pos', 'inds', d);
        if ndbFile.exist(animalprefix, 'sws')
            sws = ndb.load(animalprefix, 'sws', 'inds', d);
        end
    end

    res = util.ff.cellfetch(tetinfo, 'riptet', 'vectorize', true);
    if isempty(res.values)
        tetfilter = sprintf('isequal($area, ''%s'')', brainarea);
    else
        tetfilter = 'isequal($descrip, ''riptet'')';
    end
    tetlist =  evaluatefilter(tetinfo{d}{e}, tetfilter);
    tetlist = unique(tetlist(:,1))';
    
    % ------------------------
    % MOVEMENT : Get the exclude periods
    % ------------------------
    if string(task(d, e).type) == "run"
        % Run epochs: exclude periods are high velocity periods
        if ~isempty(velfilter)
             % get animalprefix [time, positions, velocity]
            if size(pos{d}{e}.data,2) > 5  % get velocity
                velocity = pos{d}{e}.data(:,9);% smoothed velocity
            else
                velocity = pos{d}{e}.data(:,5);
            end
            postimes = pos{d}{e}.data(:,1);  % get time stamps
            immobile = vec2list(velocity < velfilter, postimes); % generate [start end] list of immobile epochs
            excludeperiods = immobile;
        end
    else% Sleep epochs: exclude periods are non-SWS periods
         swsep = sws{d}{e};
         swslist(:,1) = swsep.starttime;
         swslist(:,2) = swsep.endtime;
         excludeperiods = swslist;
    end
    
    r = ripples{d}{e}{tetlist(1)};
    times = r.timerange(1):0.001:r.timerange(end);
    nrip = zeros(size(times)); 
    nstd=[];
    ripplestd = zeros(size(times));
    for t = 1:length(tetlist)
         tmprip = ripples{d}{e};
         if isempty(tmprip) || numel(tmprip) < tetlist(t) || isempty(tmprip{tetlist(t)})
             continue
         else
             tmprip = tmprip{tetlist(t)};
         end
         % get the indeces for the ripples with energy above minenergy
         % and maxthresh above minstd
         rvalid = find((tmprip.energy >= minenergy) & (tmprip.maxthresh >= minstd) & (isExcluded(tmprip.midtime,excludeperiods)));
         rtimes = [tmprip.starttime(rvalid) tmprip.endtime(rvalid)];
         tmpripplestd = [tmprip.maxthresh(rvalid) tmprip.maxthresh(rvalid)];
         tmprippleenergy = [tmprip.energy(rvalid) tmprip.energy(rvalid)];
         % create another parallel vector with bordering times for zeros
         nrtimes = [(rtimes(:,1) - 0.00001) (rtimes(:,2) + 0.00001)];
         rtimes = reshape(rtimes', length(rtimes(:)), 1);
         rtimes(:,2) = 1;
         tmpriplestd = [rtimes(:,1) tmpripplestd(:)];
         nrtimes = [r.timerange(1) ; reshape(nrtimes', ...
             length(nrtimes(:)), 1) ; r.timerange(2)];
         nrtimes(:,2) = 0;
         % create a new list with all of the times in it
         tlist = sortrows([rtimes ; nrtimes]);
         [junk, ind] = unique(tlist(:,1));
         tlist = tlist(ind,:);

         stdlist = sortrows([tmpriplestd ; nrtimes]);
         stdlist =stdlist(ind,:);
         nrip = nrip + interp1(tlist(:,1), tlist(:,2), times, 'nearest');
         nstd(t,:) = interp1(stdlist(:,1), stdlist(:,2), times, 'nearest');  % carry forward amplitude of ripple
    end


    %find the start and end borders of each ripple
    inripple = (nrip >= minrip);
    startrippleind = find(diff(inripple) == 1)+1;
    endrippleind = find(diff(inripple) == -1)+1;
    ripplestdout = [];
    lengthsCorrect = length(startrippleind) > 1 && length(endrippleind) > 1;
    if lengthsCorrect
        if (endrippleind(1) < startrippleind(1))
            endrippleind = endrippleind(2:end);
        end
        if (endrippleind(end) < startrippleind(end))
            startrippleind = startrippleind(1:end-1);
        end
        startripple = times(startrippleind);
        endripple = times(endrippleind);

        % Get amplitude of "global" ripple: maximum across tetrodes
        max_nstd = max(nstd,[],1);
        ampripple = max_nstd(startrippleind);
%         for i = 1:length(startripple)
%             ripplestdout(i,1) = max(ripplestd(startrippleind(i):endrippleind(i)));
%         end

        out = [startripple(:) endripple(:) ampripple(:)]; % amplitude of ripple

        out = out( ((out(:,2)-out(:,1))>.050),:);  % ripples separated by 50 ms
        out = num2cell(out, 1);
        out = table(out{:}, 'VariableNames', {'start', 'stop', 'amp'});
        out.time = (out.stop - out.start)/2 + out.start;
    else
        out = [];
        ripplestdout = [];
    end

    globalripple{d}{e} = out;
    dprev = d;

    clear out
    clear swslist
end
ndb.save(globalripple, animalprefix, name, 1)
