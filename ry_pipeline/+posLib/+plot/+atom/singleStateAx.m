function G = gridStateAx(instruction, t0)
% Plot elements of positional grid (make grid elements appear and disappear)
%
% .colors colorscheme for each block [B x 3]
% .state integer vector that controls presence or absence of state blocks
% .stateminmax  [min max]
% .label labels for each
% .colormap [values_vector, color_matrix]

uInStates = unique(instruction.state);
if ~isfield(instruction, 'possibleStates')
    instruction.possibleStates = uInStates;
end
%possibleStates = instruction.possibleStates;
%nStates = numel(possibleStates);
%if ~isfield(instruction, 'label')
%    instruction.label = repmat("", numel(possibleStates),1);
%end

G = [0, 0, 1, 1];
instruction.obj(1) = drawrectangle(instruction.ax, 'Position',G,...
    'Rotatable', false, 'InteractionsAllowed', false,...
    'Visible', 'off');
set(instruction.obj(1).Parent, 'Visible', 'off');

% Initialized value
state = instruction.state(t0);
[~,colorInd] = min(abs(state - instruction.colormap(:,1)));
color = instruction.colormap(colorInd,2:end);
set(instruction.obj,'Visible','on','EdgeAlpha',0,'Color',color);
