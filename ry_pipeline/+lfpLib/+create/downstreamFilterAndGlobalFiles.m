function downstreamFilterAndGlobalFiles(animal, day, dayDir, varargin)

ip = inputParser;
ip.addParameter('doall', false);
ip.addParameter('dothetadelta', true);
ip.addParameter('doripple', true);
ip.addParameter('globalriptets', []);
ip.parse(varargin{:})
opt = ip.Results

Info = animalinfo(animal);

% Make filtered files
eegFiles    = ndbFile.exist(animal, 'eeg',    day);
eegRefFiles = ndbFile.exist(animal, 'eegref', day);
filterDir = fileparts(which('thetafilter.mat'));
filterDir = [filterDir, filesep];

if opt.dothetadelta
    if eegFiles % low frequency defaults to unreferenced
        fprintf('Theta Filtering LFPs...\n')
        mcz_thetadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'thetafilter.mat'], 'ref', 0)
        fprintf('Delta Filtering LFPs...\n')
        mcz_deltadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'deltafilter.mat'], 'ref', 0)
    end
    if opt.doall || (~eegFiles && eegRefFiles)
        fprintf('Theta Filtering LFPs...\n')
        mcz_thetadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'thetafilter.mat'], 'ref', 1)
        fprintf('Delta Filtering LFPs...\n')
        mcz_deltadayprocess(dayDir,  Info.directDir, animal, day, 'f', [filterDir 'deltafilter.mat'], 'ref', 1)
    end
end

if opt.doripple
    if eegRefFiles % high frequency defaults to referenced
        fprintf('Ripple Filtering LFPs...\n')
        mcz_rippledayprocess(dayDir, Info.directDir, animal, day, 'f', [filterDir 'ripplefilter.mat'], 'ref', 1)
        rippletype = 'rippleref';
    end
    if opt.doall || (eegFiles && ~eegRefFiles)
        fprintf('Ripple Filtering LFPs...\n')
        mcz_rippledayprocess(dayDir, Info.directDir, animal, day, 'f', [filterDir 'ripplefilter.mat'], 'ref', 0)
        if ~exist('rippletype','var')
            rippletype = 'ripple';
        end
    end
end

% generating ripple events
if ~isempty(opt.globalriptets)
    min_suprathresh_duration = 0.015;
    nstd = 2;
    lfpLib.create.generateSPWRevents(Info.directDir, animal, day, opt.globalriptets, ...
        min_suprathresh_duration, nstd,...
        'rippletype', rippletype)
    lfpLib.create.generateGlobalRipples(animal);
    % and cortical ripples
    lfpLib.create.generateGlobalRipples(animal, 'brainarea', 'PFC', 'name', 'rippletimepfc');
end
