function spikes(animal, times, varargin)
% trial.tensorize.spikes uses trial structure to tensorize spike data

ip = inputParser;
ip.parse(varargin{:});
Opt = ip.Results;

spikes = ndb.load(animal, 'spikes');
indices = ndb.indicesMatrixForm(spikes);

spikes = ndb.toNd(spikes);
spikes = nd.label(spikes, 1:4, ["day", "epoch", "tetrode", "cell"]);

% Day epoch groups
[groups, gDays, gEpochs] = findgroups(indices(:,1:2));
uGroups = 1:max(groups);

for group = uGroups

end
