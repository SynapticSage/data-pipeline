function G = gridState(instruction, t0)
% Plot elements of positional grid (make grid elements appear and disappear)
%
% .gridTable table to sample grid regions from corresponding to state 
%   at the moment only supports gridTable of type struct
% .colors colorscheme for each block [B x 3]
% .state hot-encoding or integer vector that controls presence or absence of state blocks
% .label labels for each

if ~isfield(instruction, 'possibleStates')
    uInStates = unique(instruction.state);
    uGridStates = 1:numel(instruction.gridTable);
    possibleStates = intersect(uInStates, uGridStates);
    instruction.possibleStates = possibleStates;
end
possibleStates = instruction.possibleStates;
if ~isfield(instruction, 'label')
    instruction.label = repmat("", numel(possibleStates), 1);
end

gridTable = instruction.gridTable;
G = gobjects(1, numel(possibleStates));
for s = 1:numel(possibleStates)
    state = possibleStates(s);
    label = instruction.label(state);
    color = instruction.colors(state, :);
    width = gridTable(state).right-gridTable(state).left;
    height = gridTable(state).up-gridTable(state).down;
    radius = gridTable(state).right - gridTable(state).center_x;
    center =  [gridTable(state).center_x, gridTable(state).center_y];
    if ~isfield(instruction,'shape') || instruction.shape == "rect"
        g = [gridTable(state).left, gridTable(state).down, width, height];
        G(s) = drawrectangle('Position', g,...
            'Color', color, 'Label', label,...
            'Rotatable', false, 'InteractionsAllowed', 'none',...
            'Visible', 'on');
    elseif instruction.shape == "circle"
        G(s) = drawrectangle('Center', center, 'Radius', radius,...
            'Color', color, 'Label', char(label),...
            'InteractionsAllowed', 'none', 'Visible', 'off');
    end
end

% Initialized value
state = instruction.state(t0, :);
if isfield(instruction,'thresh')
    state(state < instruction.thresh) = 0;
end
for g = 1:numel(G)
    set(G(g), 'FaceAlpha', state(g), 'EdgeAlpha', state(g));
end
