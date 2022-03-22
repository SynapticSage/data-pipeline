function [dio, dtime, videoCue, vtime] = returnMatrices(diotable, videoCue, samprate, varargin)
% Return matrices at equal sampling rate
%
% Inputs
% ------
% dio : table type
%   diotable
%
% videoCue : table type
%   columns = [time, well_1 ... well_5]
%   
% Outputs
% -------
% dio : matrix (time x cue)
% dtime : time x 1
% videoCue : matrix (time x cue)
% vtime : time x 1
%
% Once these are returned, we have convolvable matrices that can be used to
% find an offset

assert(samprate >= 1000); % Goig to want samprate bigger than underlying dio sample rate

ip = inputParser;
ip.addParameter('pokes_negative', true);
ip.parse(varargin{:})
Opt = ip.Results;


% Convert into a curve form athat can be interpolated
dio = dioLib.generateDioCurve(diotable); % Will have to do all dios  to ensure all have matching times
% 1. Subset out cue of diotable
dio = dio(ismember(dio.type, ["cue","poke"]), :); % Subset out the cue and poke
% Now we need to get the grouping that we're going tounstack by
[ dio.grouping, utypes, ulocs ] = findgroups(dio.type, dio.location);
% delete the  propertiees that will fuck up the stacking: basically any of the
% shit that will causes rows that should be deteceted as being a part of the
% same group to not be detected as being a part of thee same group
dio.type     = [];
dio.location = [];
dio.num      = [];
dio.region   = [];

dio = unstack(dio,  'curve', 'grouping', 'NewDataVariableNames', utypes + " " + ulocs);
filt = contains( string(dio.Properties.VariableNames) , "cue");
cue = dio(:,filt);
if Opt.pokes_negative
    filt = contains( string(dio.Properties.VariableNames) , "poke");
    poke = dio(:,filt);
end

% Check that video times are unique
if ~util.isunique(videoCue.time)
    [~,ia,~] = unique(videoCue.time);
    videoCue = videoCue(ia,:);
end

% Resample each
dax    = min(dio.time):(1/samprate):max(dio.time);
vidAx  = min(videoCue.time):(1/samprate):max(videoCue.time);
iDax   = interp1(dio.time, 1:height(dio), dax, 'nearest');
iVidAx = interp1(videoCue.time, 1:height(videoCue), vidAx, 'nearest');

% Return
dio = cue;
if Opt.pokes_negative
    quantileFunc = @(x) -quantile(table2array(x), 0.99) + quantile(table2array(x),0.01);
    Q = arrayfun(@(j) quantileFunc(videoCue(:,j)), 2:size(videoCue,2),...
        'UniformOutput',false);
    Q = cat(2, Q{:});
    Q = repmat(Q, height(poke), 1);
    poke = double(properMatrix(poke));
    dio =  double(properMatrix(dio));
    poke(:,1:5) = poke(:,1:5)  .* Q;
    dio(:,1:5) = dio(:,1:5) + poke(:,1:5) .* dio(:,1:5); %TODO test this term addition,  where  a  poke will only cause a negativity if dio already on
end

% Finalizee outputs
dio      = dio(iDax, :);
dtime   =  dax;
videoCue = table2array(videoCue(iVidAx, 2:end));
vtime    = vidAx;

function X = properMatrix(X)
    nums = string(X.Properties.VariableNames);
    nums = split(nums', " ");
    nums = str2double(nums(:,2));
    tmp = nan(height(X), 5);
    tmp(:, nums) = table2array(X);
    X = tmp;
