function newtable = throwOutFlicker(diotable,varargin)
% THROWOUTFLICKER Tosses out any flicker on dios

ip = inputParser;
ip.KeepUnmatched = true;
ip.addParameter('ploton', true);
ip.addParameter('filt', true(height(diotable),1), @islogical);
ip.addParameter('groupFields', ["day","epoch","num"],...
    @(x) iscellstr(x) || isstring(x));
ip.addParameter('pulseFind', false, @(x) isnumeric(x) ||  islogical(x));
ip.addParameter('pulse_isi_thresh', 20); % either the threshold for flicker or the maximal threshold for flicker 1/4 second
ip.addParameter('skipType', ["cue","reward"]); % either the threshold for flicker or the maximal threshold for flicker 1/4 second
ip.parse(varargin{:});
opt = ip.Results;
disp("Removing flicker")

diotable = diotable(opt.filt,:);

% Compute which group fields to use
opt.groupFields = string(opt.groupFields);
opt.groupFields = union(opt.groupFields, ["num","direction"]);
opt.groupFields = intersect(opt.groupFields,...
    string(diotable.Properties.VariableNames));

% Inputs only!
%inputs =  diotable.direction== "input";

%% Throw away any flicker faster than 1 second
% find groups of interest
groups = arrayfun(@(x) diotable.(x), opt.groupFields, 'UniformOutput', false);
groups = findgroups(groups{:});
newtable = table();
for g = unique(groups)'

    % Sort table by time
    D = diotable(groups == g, :);
    D = sortrows(D,'time');

    % Do  not process certain dio types  given by user
    if all(ismember(D.type, opt.skipType))
        newtable = [newtable; D];
        continue
    end

    % Lets add diodiff
    statefilter = D.state == 1;
    X = diff(sort(D(statefilter,:).time));
    X = [inf; X];                   % first isi will be inf per id
    D.diodiff = inf(size(D.state));
    D(statefilter,:).diodiff = X;

    % Do we let an automated algorithm find the timescale of flips?
    if opt.pulseFind
        [inds, ~, threshold_range] = dioLib.pulseFind(D.state, D.time);
        opt.pulse_isi_thresh = min(mean(threshold_range(1,:)), opt.pulse_isi_thresh);
    end

    % Filter out any dio subthreshold entires
    %before = height(D);
    accept = D.diodiff > opt.pulse_isi_thresh;
    interveningPokes = getInterveningPokes(D, diotable); % per interval from state=1 to state=1 at two consecutive times, returns if (how many) intervening pokes on different wells
    accept = accept | interveningPokes > 0;
    while ~all(accept)
        fprintf('\nType=%s, Location=%d, Mean percent of pulses removing -> %2.1f\n', ...
            D(1,:).type, D(1,:).location, 100*mean(~accept)*2);
        reject = find(~accept);
        reject = unique([reject, reject-1]); % remove the poke and the OFF state before it (to bridge/unify the two  pokes  into one)
        reject(reject==height(D)+1) = []; 
        reject(reject==0) = []; 
        D(reject, :) = [];
        accept = D.diodiff > opt.pulse_isi_thresh;
        interveningPokes = getInterveningPokes(D, diotable); % per interval from state=1 to state=1 at two consecutive times, returns if (how many) intervening pokes on different wells
        accept = accept | interveningPokes > 0;
    end
    %after = height(D);

    D.diodiff = [];

    % Now replace our original entires
    newtable = [newtable; D];
end


disp("Size reduction: " + num2str(height(diotable)/height(newtable)))

if opt.ploton
    fig('dio before flickerRemove');
    dioLib.plotDioCurve(diotable);
    sgtitle('DIO before flicker removal')
    fig('dio after flickerRemove');
    dioLib.plotDioCurve(newtable);
    sgtitle('DIO after flicker removal')
end

% ----------------------------------------------------------------------
function N = getInterveningPokes(D, dio)
% Per interval from state=1 to state=1 at two consecutive times, returns if
% (how many) intervening pokes on different wells 

    type = D.type;
    assert(all(type == type(1)));
    type = type(1);

    N = zeros(height(D), 1);
    if type == "poke"
        location = D.location;
        assert(all(location == location(1)));
        location = location(1);
        dio = dio(dio.location ~= location & dio.type == "poke", :);

        for i = 2:height(D)
            N(i) = sum(D.time(i-1) < dio.time & D.time(i) > dio.time); 
        end
    end
% ----------------------------------------------------------------------
%function N = pathLength(D, pos)
% Function returns path length of animal motion between two time points
