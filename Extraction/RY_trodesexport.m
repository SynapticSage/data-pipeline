function RY_trodesexport(binaries, flags, varargin)
% 
% Based on RN_exportBinary. Trodes 2.0 saw the 
% new trodesexport unified method of export. This is
% an update to accomadate that. Two benefits:
%
% - trodesexport supports filetypes that the classic
% version does not
% - trodesexport is faster because it makes fewer
% iterative crawls through a rec file than the classic
% method
%

parser = inputParser;
parser.addParameter('background_execute', 0);
parser.parse(varargin{:});
opt = parser.Results;

assert(iscell(binaries), 'binary must be a cell of desired binary exports');

binaries = string(binaries(:))';
for binary = binaries
    switch char(binary)
        case 'lfp'
        case 'raw'
        case 'spikeband'
        case 'time'
        case 'dio'
        case 'analogio'
        case 'stim'
        case 'mountainsort'
        case 'kilosort'
        otherwise
            h = msgbox([binary ' not a valid binary export type. Please choose: LFP, spikes, time, dio, mda, or phy']);
            waitfor(h);
    end
end
binaries = join("-" + binaries, " ");

%Find the path to the extraction programs
trodesPath = which('trodes_path_placeholder.m');
if isempty(trodesPath)
    error('trodes path not found')
end
trodesPath = fileparts(trodesPath);



if ispc

    command = ['"',fullfile(trodesPath,['export' binary]),'"', flags];
    disp(command);
    eval("!" + command);

else %UNIX

    escapeChar = '\ ';
    trodesPath = strrep(trodesPath, ' ', escapeChar);
    % Creat a logFileDescriptor?
    if ~isempty(flags)
        %logFileDescriptor = ['_' replace(flags,' ','_')];
        logFileDescriptor = '';
    else
        logFileDescriptor = '';
    end
    % Log file name
    logname = ['export' binary logFileDescriptor '.log'];
    % Execute
    if opt.background_execute
        assert(isunix(), 'Must be a unix system to process in parallel')
        command_version_print = ['!',fullfile(trodesPath,['export' binary])  ' -v' ' &> ' logname '&'];
        command = ['!',fullfile(trodesPath,['export' binary]), flags, ' &> ' logname '&'];
    else
        command_version_print = ['!',fullfile(trodesPath,['export' binary])  ' -v'];
        command = ['!',fullfile(trodesPath,['export' binary]), flags];
    end
    disp(command)
    eval(command_version_print)
    eval(command)

end

