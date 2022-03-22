function ml_create_marks(tetResDir, varargin)
% Extracts marks.mda from moutainsort data via pyms.extract_clips

ip = inputParser;
ip.addParameter('overwrite', false);
ip.addParameter('clip_size', 1); % Default 1 data point, ie just the peak amplitude on each channel
ip.parse(varargin{:})
Opt = ip.Results;

if tetResDir(end)==filesep
    tetResDir = tetResDir(1:end-1);
end

% Firings and timeseries files
firings_out = [tetResDir filesep 'firings_raw.mda'];
timeseries = [tetResDir filesep 'pre.mda'];

% Optional mark extraction
markfile = sprintf('%s%smarks.mda',tetResDir,filesep);
if Opt.overwrite || ~exist(markfile,'file')
    extractInputs.timeseries = timeseries;
    extractInputs.firings    = firings_out;
    extractOutputs.clips_out = markfile;
    extractParams = struct('clip_size', Opt.clip_size);
    pName = 'pyms.extract_clips';
    ml_run_process(pName,curInputs,curOutputs,curParams);
end

