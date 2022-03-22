function [dio, timestamps, threshold_ranges] = pulseFind(dio, timestamps, varargin)
% Purpose: Automatically figure out the timestamp times at which the laser pulse
% turns on and off .. without knowing anything about the pulse pattern
% uploaded through FSGui
%
% NOTE
% ----
% Function is broken for now

recurse = 1; % Number  of times to recursively look for pulsing substructure
% (2, for examplee would not only look for single bursts, but rather, burst of
%         bursts)
conservative_threshold_peak_decay = 0.025;
squeeze_extra_zeros = false; 
optlistassign(who, varargin{:});

% Dio empty? return emptiness
if sum(dio) == 0
    pulse_on = [];   % whenever the pulse is on
    ts_on    = [];
    return;
end

% Recursively find a solution
[dio, threshold_ranges]  = recurseFind(dio, timestamps, recurse,...
    conservative_threshold_peak_decay);

% Squeeze out extra zeros?
if squeeze_extra_zeros
    zeros_to_remove = [diff(find(dio == 0)) == 0, 1];
    dio(zeros_to_remove)        = [];
    timestamps(zeros_to_remove) = [];
end

%% HELPER FUNCTIONS
function [dio, threshold_ranges] = recurseFind(dio, timestamps, recurse,...
        threshold_out_decay)

    threshold_ranges = nan(recurse, 2);
    for r = 1:recurse
        
        % Retrieve the smallest interpulse interval range
        smallest_jmp = findSmallestPulseDiff(dio, timestamps, threshold_out_decay);

        % Calculate pulse ons
        ind_dios = find(dio);
        timeons = timestamps(ind_dios);
        deltas  = diff(timeons);

        % Get desired indices
        desired_set = find( mean(smallest_jmp) <= deltas );
        %desired_set = setdiff(ind_dios,ind_dios([indx]));

        pulse = false(size(dio));
        pulse(desired_set) = true;
        
        % Calculate pulse offs
        dio = pulse;

        threshold_ranges(r,:) = smallest_jmp;
    end

% -------------------------------------------------------------------------
function smallest_jmp_range = findSmallestPulseDiff(dio, timestamps,...
        threshold_out_decay)

    % Grab diff of the dio pattern
    dio_on_ind = find((dio == 1));
    timestamp_change = timestamps(dio_on_ind);

    if isempty(dio_on_ind)
        warning('No pulses in DIO');
        smallest_jmp=[0 0];
    end

    min_diff = min(timestamp_change);
    max_diff = max(timestamp_change);

    % Bin counts to explore
    bincount = log10(max_diff+min_diff) - log10(eps(timestamp_change(1)));
    bincount = round(bincount*5);

    % Compute edges for the binning process
    edges = logspace(log10(eps(timestamp_change(1))),log10(max_diff+min_diff),bincount+2);

    % Compute bin count
    [N, edges] = histcounts(timestamp_change, edges);

    % Compute the idx containing the pulse count
    [~, pulse_candidate]=max(N);


    % We're not just going to accept the most common highest peak, rather, we want to grab area under the curve well into the peak's decay
    while N(pulse_candidate+1) > threshold_out_decay * N(pulse_candidate) 
        pulse_candidate = pulse_candidate + 1;
    end

    % We'll say the pulse range is somewhere in here
    smallest_jmp_range = [edges(pulse_candidate) edges(pulse_candidate+1)];

    keyboard
    figure(101);
    histogram(timestamp_change, edges);
    set(gca,'xscale','log');
    vline(smallest_jmp_range(1))
    vline(smallest_jmp_range(2))
