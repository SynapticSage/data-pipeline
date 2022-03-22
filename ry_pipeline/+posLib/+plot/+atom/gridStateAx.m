function G = gridStateAx(instruction, t0)
% Plot elements of positional grid (make grid elements appear and disappear)
%
% .colors colorscheme for each block [B x 3]
% .state hot-encoding or integer vector that controls presence or absence of state blocks
% .label labels for each
% .backgroundColor 
% .possibleStates
% .orientation

uInStates = unique(instruction.state);
if ~isfield(instruction, 'possibleStates')
    instruction.possibleStates = uInStates;
end
possibleStates = instruction.possibleStates;
nStates = numel(possibleStates);
if ~isfield(instruction, 'label')
    instruction.label = repmat("", numel(possibleStates),1);
end

X = xlim();
Y = ylim();

% Determine bounds
for s = 1:numel(possibleStates)
    if instruction.oriention == "v"
        height = range(Y) / nStates;
        width  = range(X);
        bottom = Y(1) : width : Y(end);
        bottom = bottom(1:end-1);
        left   = repmat(X(1), size(bottom));
    elseif instruction.orientation == "h"
        height = range(Y);
        width  = range(X) / nStates;
        left = X(1) : width : X(end);
        left = left(1:end-1);
        bottom   = repmat(X(1), size(left));
    end
end

for s = 1:numel(possibleStates)
    state = possibleStates(s);
    label = instruction.label(state);
    color = instruction.colors(state, :);
    G = [left(s), bottom(s), width(s), height(s)] 
    instruction.obj(s) = drawrectangle('Position',G,...
        'Color', color, 'Label', label,...
        'Rotatable', false, 'InteractionsAllowed', false,...
        'Visible', 'off');
end

% Initialized value
state = possibleStates(t0);
on_states = instruction.possibleStates(ismember(possibleStates, state));
off_states = instruction.possibleStates(~ismember(possibleStates, state));
instruction.obj(on_states).Visible = 'on';
instruction.obj(off_states).Visible = 'on';
