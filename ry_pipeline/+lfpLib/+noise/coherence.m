function noiseStruct = coherence(animal, day, tetrode)
% Detects noise via periods of zero phase lag coherence and
% broadband coherence.
%
% ISSUES
% ------
% Tetrode or all tetrode?

ip = inputParser;
ip.addParameter('resolution', 0.025); %50 millisecond
ip.addParameter('tetinfoTable', []); %50 millisecond
ip.parse(varargin{:})
Opt = ip.Results;

% -----------------------
% Get tetrode information
% -----------------------
if isempty(Opt.tetinfoTable)
    Opt.tetinfo = ndb.load(animal, 'tetinfoTable');
    Opt.tetinfo = Opt.tetinfo(Opt.tetinfo.day==day, :);
end

resolution_acheived = false;
if ndb.exist(animal, 'cgramcnew')

    cgramc = ndb.load(animal, 'cramgcnew', 'inds', day, 'get', true);

    cgramc = ndb.toNd(cgramc);
    inner_dims_of_struct = 1;
    outer_dims_of_data   = 1;
    cgramc               = nd.cat(cgramc, inner_dims_of_struct, outer_dims_of_data);

    % we need a certain resolution
    if cgramc.movingwin(1) < Opt.resolution
    end
end

if ~resolution_acheived
    eeg    = ndb.load(animal, 'eeg', 'inds', day, 'get', true);
    cgramc = ry_calccoherence(index, eeg, 'doavgeegtets', true);
    error('Not implemented')
end

%% ZERO LAG COHERENCE NOISE
TIME = 1;
FREQ = 2; 
penalize_closeness_to_zero_phase_lag = (pi^2 -(circ_dist(cgramc.phi, 0).^2));
noiseStruct.zeroLagCoherence         = mean(penalize_closeness_to_zero_phase_lag .* cgramc.C, FREQ);
noiseStruct.zscoreZeroLagCoherence   = zscore(potential_noise);
