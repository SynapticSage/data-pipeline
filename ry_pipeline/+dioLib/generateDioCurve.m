function varargout = generateDioCurve(dio, filt, varargin)
%
% filt : numeric or logical
%   if numeric, those are dio nums
%   if logical, it treats  it as a rowfilter for dio table

ip = inputParser;
% Curve options
ip.KeepUnmatched = true;
ip.addParameter('pointBeforeStateTransition', true);
ip.addParameter('shareTimeAx', true);
ip.addParameter('nanpad', false);
ip.addParameter('removeFlicker', false);
ip.parse(varargin{:})
Opt = ip.Results;

epsilon = 5e-10; 

if ~istable(dio)
   error('This function accepts dioTable only.  Please use generateDioTables.m')
end

if nargin == 1 || isempty(filt)
    uNums = unique(dio.num);
    filt = true(height(dio),1);
elseif islogical(filt)
    uNums = unique(dio(filt,:).num);
elseif isnumeric(filt)
    uNums = filt;
    filt  = true(height(dio),1);
end

reducedDio = dio(filt,:);

if Opt.removeFlicker
    unmatched = ip.Unmatched;
    reducedDio = dioLib.throwOutFlicker(reducedDio, unmatched); % TODO do not remove flickers where the animal moves away from the well (a certain radius/path_distance) and comes back to poke
end

[groups, uDay, uEpoch, uNumsAll] = findgroups(reducedDio.day, reducedDio.epoch, reducedDio.num);
groups(~ismember(uNumsAll(groups), uNums)) = -1;
uGroups = unique(groups);
curveTable = table();
for group = uGroups'
    if group == -1
        continue
    end

    dioNum = uNumsAll(group);
    day    = uDay(group);
    epoch  = uEpoch(group);

    groupFilter = group == groups;
    if ~any(groupFilter)
        continue
    end

    c = reducedDio(groupFilter, 'state');
    time  = reducedDio(groupFilter, 'time');
    first = find(groupFilter,1,'first');
    c = table2array(c);
    time = table2array(time);
    if Opt.pointBeforeStateTransition
        % Add points  right before state transitions
        curve = [c, c];
        curve(c==0, 2) = 1; 
        curve(c==1, 2) = 0; 
        curve(c==0, 2) = 1; 
        curve(c==1, 2) = 0; 
        time = [time, time];
        time(:,2) = time(:,2) - epsilon;
        curve = curve';
        time = time';
    end
    time = time(:);
    curve = curve(:);

    day   = repmat(day, numel(time), 1); epoch = repmat(epoch, numel(time), 1);
    num   = repmat(dioNum, numel(time), 1);
    type   = repmat(table2array(reducedDio(first,'type')), numel(time), 1);
    location   = repmat(table2array(reducedDio(first,'location')), numel(time), 1);
    region   = repmat(table2array(reducedDio(first,'region')), numel(time), 1);
    groupTable  = table(day, epoch, num, time, curve, type, region, location);
    curveTable = [curveTable; groupTable];
end

% if shareTimeAx then all dio nums are sampled at the same times
if Opt.shareTimeAx && height(curveTable)>0
    newTable = table();
    curveTable = sortrows(curveTable, 'time');
    [days, uDays] = findgroups(curveTable.day);
    for d = unique(days)'
        subCT = curveTable(days == d, :);
        allTime = unique(subCT.time);
        nums  = findgroups(subCT.num);
        dayTable=table();
        for n = unique(nums)'
            groupTable = subCT(n == nums,:);
            if height(groupTable)==0
                continue
            end
            [~, first, ~] = unique(groupTable.time, 'first');
            if numel(first) ~= height(groupTable)
                warning('%d of %d non-unique times', height(groupTable)-numel(first), height(groupTable))
                keyboard
                groupTable = groupTable(first,:);
            end
            inds = interp1(groupTable.time, 1:height(groupTable), allTime, 'nearest', 'extrap');
            groupTable  = groupTable(inds,  :);
            groupTable.time = allTime;
            dayTable = [dayTable; groupTable];
        end
        % Check times equal for all available dio num
        times = [];
        for num = unique(dayTable.num)'
            times = [times,dayTable(dayTable.num == num, :).time];
        end
        times = num2cell(times,1);
        try
            if numel(times)>1
                assert(isequal(times{:}));
            end
            disp("ShareAx confirmed day " + uDays(d))
        catch ME
            error("Times not same");
        end
        newTable = [newTable; dayTable];
    end
    curveTable = newTable;
    clear newTable;
end


% Insert nans after each epoch?
if Opt.nanpad
    [epochStartTimes, epochStopTimes] = dioLib.epochTimes(dio);
    dioLib.insertTableValue(curveTable, epochStartTimes + epsilon, 0, "what", "curve");
    dioLib.insertTableValue(curveTable, epochStopTimes + epsilon, nan, "what", "curve");
    disp("nanpad")
else
    disp("no nanpad")
end

% Send outputs to multiple args or one table?
if nargout <= 1
    varargout{1} = curveTable;
else
    uNums = unique(curveTable.num)';
    n = numel(uNums);
    varargout = cell(1, n);
    for uNum  = 1:n
        varargout{uNum} = curveTable(curveTable.num == uNum,:);
    end
end
