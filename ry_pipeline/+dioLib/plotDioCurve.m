function [ax, dio] = plotDioCurve(dio, nums, dayepoch, varargin)
% PlotOption
ip = inputParser;
ip.KeepUnmatched = true;
ip.addParameter('stacked', "stackByType"); % options: none, stack, stackByType, stackByLocation
ip.addParameter('color',   "colorByLocation"); % options: none, color, colorByType, colorByLocation
ip.addParameter('cmocean',   "phase"); % options: none, color, colorByType, colorByLocation
ip.addParameter('ax',   []); % options: none, color, colorByType, colorByLocation
ip.addParameter('extraAxes', 0);
ip.addParameter('rawpos',   false) % Add pos plot?
ip.addParameter('pos',   false) % Add pos plot?
ip.addParameter('offset',   0) % Add pos plot?
ip.parse(varargin{:})
Opt = ip.Results;

% Validate
days = unique(dio.day);
if numel(days) > 1 && ((nargin  < 3)  || isempty(dayepoch))
    error('This method currently does not support multiple days! %s', num2str(days'))
end

% Set day epoch
if  nargin >= 3
    if numel(dayepoch) ==  2
        dio = dio(dio.day == dayepoch(1) & dio.epoch == dayepoch(2), :);
    elseif numel(dayepoch) == 1
        dio = dio(dio.day == dayepoch(1),  :);
    else
        error("Too many digits in dayepoch")
    end
end

% Acquire num properties
dio = sortrows(dio, 'num');
subdio = dio(find([1; diff(dio.num)]),:); % get first entry per dio
if nargin  <= 1 || isempty(nums)
    nums = subdio.num;
end
dio =  dio(ismember(dio.num, nums),:);
if ~istable(dio) || ~ismember("curve", string(dio.Properties.VariableNames))
    unmatched=ip.Unmatched;
    unmatched.shareTimeAx = true;
    unmatched.nanpad = false;
    dio = dioLib.generateDioCurve(dio, nums, unmatched);
end
dio = sortrows(dio, 'num');
subdio = dio(find([1; diff(dio.num)]),:); % get first entry per dio


% Get stack  groups
switch char(Opt.stacked)
    case 'stack',
    stack = findgroups(dio.nums);
    stackProp = "nums";
    case 'stackByType'
    stack = findgroups(dio.type);
    stackProp = "type";
    case 'stackByLocation'
    stack = findgroups(dio.location);
    stackProp = "location";
    case 'none'
    stack = ones(height(dio),1);
    otherwise
    error('not  a  valid option')
end
uStack = unique(stack);
nStack = numel(uStack);

multiEpoch = numel(dio.epoch) > 1;
if multiEpoch
    [epochStartTimes,~] = dioLib.epochTimes(dio);
end

% Get color  groups
switch char(Opt.color)
    case 'color',
    color = findgroups(subdio.num);
    case 'colorByType'
    color = findgroups(subdio.type);
    case 'colorByLocation'
    color = findgroups(subdio.location);
    case 'none'
    color = ones(height(subdio),1);
    otherwise
    error('not  a  valid option')
end
uColor = unique(color);
nColor = numel(uColor);

Opt.cmocean = char(Opt.cmocean);
switch Opt.cmocean
    case 'phase'
    colors = cmocean(Opt.cmocean, nColor+1);
    colors = colors(2:end,:);
    otherwise
    colors = cmocean(Opt.cmocean, nColor)
end

if isempty(Opt.ax)
    if Opt.pos
        ax = arrayfun(@(x) subplot(nStack+1+Opt.extraAxes, 1, x), 1:nStack+1+Opt.extraAxes);
    else
        ax = arrayfun(@(x) subplot(nStack+Opt.extraAxes,1, x), 1:nStack+Opt.extraAxes);
    end
else
    ax = Opt.ax;
end

% Plot stacked objects
areaobjs = [];
areaobjNum = [];
areaobjType = [];
nums = sort(nums);
for s = 1:nStack
    filt = stack==s;
    first =  find(filt,1,'first');
    times = dio(filt,'time');
    curves = arrayfun(@(num) table2array(dio(dio.num==num & filt,'curve')), nums,...
        'UniformOutput', false);
    empty  = cellfun(@isempty, curves);
    curves = curves(~empty);
    curves = cat(2,curves{:});
    time = arrayfun(@(num) table2array(dio(dio.num==num & filt,'time')), nums,...
        'UniformOutput', false);
    time = time(~empty);
    time = cat(2,time{:});
    areaobjs = [areaobjs, area(ax(s), time-Opt.offset, curves)];
    areaobjNum = [areaobjNum, nums(~empty)'];
    %areaobjType = [areaobjType, nums(~empty)'];
    title(ax(s), stackProp + " = " + table2array(dio(first, stackProp)));

    if multiEpoch
        line(ax(s), repmat(epochStartTimes',2,1), repmat(ylim(ax(s))', 1, numel(epochStartTimes)),...
            'LineStyle', ':', 'Color','k',...
            'linewidth',4); 
    end
    ax(s).Tag = table2array(dio(first, stackProp));
end

if Opt.pos
    pos = ndBranch.load('RY16','pos', 'indices', dio(1,:).day);
    pos = cellfetch(pos, 'data');
    pos = cat(1,pos.values{:});
    plot(ax(end), pos(:,1), pos(:,2), pos(:,1), pos(:,3),'k-');
end

if Opt.rawpos
    pos = ndBranch.load('RY16','rawpos', 'indices', dio(1,:).day);
    pos = cellfetch(pos, 'data');
    pos = cat(1,pos.values{:});
    plot(ax(end), pos(:,1), pos(:,2), pos(:,1), pos(:,3),'k-');
end

%  Color objects
for c = uColor(:)'
    filt = color == c;
    numFilt = nums(filt);
    %=subdio(filt,:);
    set(areaobjs(ismember(areaobjNum, numFilt)),...
        'FaceColor', colors(c,:),...
        'EdgeColor', 'none',...
        'FaceAlpha',0.60);
end

linkaxes(ax, 'x');
set(gca,'xlim', [min(dio.time)-1,max(dio.time)+1]);
