function statematrix = getMatrix(animal, dayepoch, query_time, direction, type)

if nargin < 4
    direction = "input";
end
if nargin < 5
    type = "poke";
end

eta = 1/30; % frame period

diotable = ndb.load(animal,'diotable', 'indices', dayepoch, 'get', true);
if ~istable(diotable)
    diotable = tidyData.icatNdb(diotable);
end
diotable = diotable(diotable.direction == direction, :);
diotable = diotable(diotable.type == type, :);
[groups, locations] = findgroups(diotable.location);
newstate = cell(numel(locations), 1);
duplicated = util.getduplicates_logical(query_time);
qtnondup   = query_time(~duplicated);
for group = unique(groups)'
    subtable           = diotable(groups == group, :);
    time               = double(subtable.time);
    tdups = util.getduplicates_logical(time);
    time               = time(~tdups);
    state              = double(subtable.state(~tdups));
    location           = locations(group);
    newstate{location} = nan(size(query_time));
    newstate{location}(~duplicated) = single(interp1(time, state, qtnondup, 'previous')); % interpolate a point to whatever previous sample said
    newstate{location}(qtnondup > max(time) + eta) = nan;
    newstate{location}(qtnondup < min(time) - eta) = nan;
end
statematrix = cat(2, newstate{:});

zero_nans_here= sum(isnan(statematrix), 2) < size(statematrix,2);
statematrix(zero_nans_here & isnan(statematrix)) = 0;
