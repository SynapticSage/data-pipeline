function axs = axes(fighandle, varargin)
% Initializes axes for moving position plot videos

ip = inputParser;
ip.addParameter('margin',  [0.06 0.06]);
ip.addParameter('spacing', [0.05 0.05]);
ip.addParameter('tiling',  5);
ip.addParameter('plots',   [0]);  %Sets of each type of plot
ip.addParameter('plotPositions', {'left'});
ip.addParameter('plotDir', []); % 1 along rows, 2 along columsn
ip.addParameter('plotNames',{});
ip.parse(varargin{:})
Opt = ip.Results;
Opt.plotNames     = string(Opt.plotNames);
Opt.plotPositions = string(Opt.plotPositions);
clf

M = Opt.margin; % Margin at edge of axes
S = Opt.spacing; % Spacing between axes

nAxs = sum(Opt.plots) + 1;
axs = gobjects(nAxs,1); 
iAx = 0;

if isempty(Opt.plotDir)
    for ii = 1:numel(Opt.plots)
        switch Opt.plotPositions(ii)
            case {'left','right'}
                Opt.plotDir(ii) = 1;
            case {'bottom','top'}
                Opt.plotDir(ii) = 2;
            case 'behind'
        end
    end
end
counters = struct('left',0,'right',0,'top',0,'bottom',0,'behind',0);
if isempty(Opt.plotNames)
    for ii = 1:numel(Opt.plots)
        pos =  Opt.plotPositions(ii);
        counters.(pos) = counters.(pos) + 1;
        Opt.plotNames(ii) = string(pos) + "_" + counters.(pos);
    end
end

%% DETERMINE THE MAIN AREA
%% -----------------------
usedRegion = struct('left',0,'right',0,'top',0,'bottom',0);
for ii = 1:numel(Opt.plots)

    if ~isempty(Opt.plotPositions(ii))
        rowOrCol = Opt.plotPositions(ii);
        if ismember(rowOrCol,["left","right"])
            if Opt.plotDir(ii) == 1
                spaceFilling = Opt.plots(ii);
            else
                spaceFilling = 1;
            end
        elseif ismember(rowOrCol,["top","bottom"])
            if Opt.plotDir(ii) == 2
                spaceFilling = Opt.plots(ii);
            else
                spaceFilling = 1;
            end
        else
            continue
        end
        usedRegion.(rowOrCol) = usedRegion.(rowOrCol) + 1*spaceFilling;
    end

end
left_start   = M(1) + usedRegion.left/Opt.tiling;
bottom_start = M(1) + usedRegion.bottom/Opt.tiling;
right_occupied = usedRegion.right/Opt.tiling
top_occupied   = usedRegion.top/Opt.tiling;
width  = 1 - M(1) - left_start   - right_occupied;
height = 1 - M(2) - bottom_start - top_occupied;
mainRegion = [left_start, bottom_start, width, height];

%% INIT ALL NON-MAIN AXES
for ii = 1:numel(Opt.plots)
    % Basic properties
    % ----------------
    total_spacing = S * Opt.plots(ii);
    pdir = Opt.plotDir(ii);

    % INITIALIZE LONG RECTANGULAR
    % ---------------------------
    switch Opt.plotPositions(ii)
        case 'bottom'
            C_act = [0,0];
            S_act = [0,0];
            S_act(pdir) = (1-2*M(2))/Opt.plots(ii);
            S_act(pdir) = S_act(pdir) + S(pdir);
        case 'left'
            C_act = [0,1];
            S_act = [0,0];
            S_act(pdir) = -(1-2*M(2))/Opt.plots(ii);
            S_act(pdir) = S_act(pdir) - S(pdir);
        case 'right'
        case 'top'
        case 'behind'
        otherwise
            error('Unrecognized option');
    end
    for jj = 1:numel(S_act)
        if sign(S_act(jj)) == 1
            initial(jj) = 1;
        elseif sign(S_act(jj)) == -1
            initial(jj) = 0;
        end
    end

    % Determine how to Move
    for jj = 1:Opt.plots(ii)
        iAx = iAx + 1;
        corner(1) = M(1) + C_act(1) + S_act(1)*(jj-initial(1));
        corner(2) = M(2) + C_act(2) + S_act(2)*(jj-initial(2));
        if ismember(Opt.plotPositions(ii),["left","right"])
            WidHeight(1) = (1 - M(1)*2)/Opt.tiling;
            WidHeight(2) = (1 - M(2)*2)/Opt.plots(ii);
        elseif ismember(Opt.plotPositions(ii), ["top","bottom"])
            WidHeight(2) = (1 - M(2)*2)/Opt.tiling;
            WidHeight(1) = (1 - M(1)*2)/Opt.plots(ii);
        end
        axs(iAx) = axes('Position', [corner, WidHeight]);
        axs(iAx).Tag = Opt.plotNames(ii) + "_" + jj;
    end

end

% Add any axes spec'd as behind
% -----------------------------
if counters.behind == 1
    behindRegion = mainRegion;
    behindRegion(1) = mainRegion - opt.spacing(1)/2;
    behindRegion(2) = mainRegion - opt.spacing(2)/2;
    behindRegion(3) = mainRegion + opt.spacing(1)/2;
    behindRegion(4) = mainRegion + opt.spacing(2)/2;
    iAx = iAx + 1;
    axs(iAx) = axes('Position', mainRegion,'visible','on');
    axs(iAx).Tag = 'uSingleStateAx'; % only type of axis right now supported behind
elseif counters.behind == 0
else
    error('More than one axis behind the main not implemented!')
end


% Finally, we add the main axes!
% ------------------------------
iAx = iAx + 1;
axs(iAx) = axes('Position', mainRegion,'visible','on')
axs(iAx).Tag = 'main';
