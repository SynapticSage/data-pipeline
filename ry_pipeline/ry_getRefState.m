function refState = ry_getRefState(varargin)
% Returns whether a config file is requesting referening in the export
% 
% Sources of knowledge can either be in the LFP.mat files themselves
% (receommended) or from the xml config file for the recording.

ip = inputParser;
ip.addParameter('lfp', true);
ip.addParameter('animal', []);
ip.addParameter('configDir',[]);
ip.addParameter('configFile',[]);
ip.addParameter('inds',[]);
ip.parse(varargin{:})
opt = ip.Results;

if ~isempty(opt.animal)
    info = animalinfo(opt.animal);
    opt = util.struct.update(opt, info);
end


%  OBTAINING REFERENCE STATE FROM THE CONFIG FILE
if opt.lfp % FROM LFP MAT FILES
    disp("Using lfp check")

    % Obtain the referenced data
    lfp = ndb.load(opt.animal, 'eeg', 'inds',  opt.inds);
    referenced = cellfetch(lfp, 'referenced');

    % Obtain consensus
    if ~isequal(referenced.values{:})
        warning("No consensus on referencing across lfp files")
        keyboard
    end
    referenced  = cat(1,referenced.values{:});
    refState =  referenced;

elseif ~isempty(opt.configFile) && exist(opt.configFile,'file')
    disp("Using referening check within configFile (refOn states)")

    [direct, cfFile, ext] = fileparts(opt.configFile);
    currDir = pwd;
    des = onCleanup(@() cd(currDir));
    cd(direct);
    xml = xml2struct([cfFile ext]);
    spikeNtrode = [xml.Configuration.SpikeConfiguration.SpikeNTrode{:}];
    attributes = {spikeNtrode.Attributes};
    refOn = cellfun(@(x) str2double(getfield(x,'refOn')), attributes);

    refState = refOn;

else
    error('Pleease provide configFile or configDir')
end


