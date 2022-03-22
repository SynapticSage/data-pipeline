function G = positionGridState(instruction, t0)
% function G = positionGridState(instruction, t0)
% Plot elements of positional grid (make grid elements appear and disappear)
%
%
%    ---------------------
%    % Required inputs
%    -----------------
%    state   time x state
%
%    ---------------------
%    Inferrable inputs
%    ---------------------
%    possibleStates state
%
%    ---------------------
%    Preprocessed inputs
%    ---------------------
%    color   time x state x channel OR (value x channel x state)
%
%    ---------------------
%    % Default inputs
%    -----------------
%    label   state
%    width   time x state x 1
%    height  time x state x 1
%    radius  time x state x 1
%    center  time x state x 2
%    showText bool = false

if ~isfield(instruction, 'possibleStates')
    instruction.possibleStates = 1:size(instruction.state, 2);
end

possibleStates = instruction.possibleStates;
if ~isfield(instruction, 'label')
    instruction.label = repmat("", numel(possibleStates), 1);
end

G = gobjects(1, numel(possibleStates));
for s = 1:numel(possibleStates)

    label  = instruction.label(s);          % state
    color  = instruction.color(1, s, :);   % time x state x channel
    width  = instruction.width(1, s, 1);    % time x state x 1
    height = instruction.height(1, s, 1);   % time x state x 1
    radius = instruction.radius(1, s, 1);   % time x state x 1
    center = instruction.position(1, s, :); % time x state x 2

    left   = center(1) - width/2;
    down   = center(2) - height/2;

    % Construct a circle or square at the proper location
    if ~isfield(instruction,'shape') || instruction.shape == "rect"
        g = [left, down, width, height];
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

% -----------------
% Initialized value
% -----------------
state = instruction.state(t0, :);
if isfield(instruction,'thresh')
    state(state < instruction.thresh) = 0;
end

for g = 1:numel(G)
    set(G(g), 'FaceAlpha', state(g), 'EdgeAlpha', state(g));
end

