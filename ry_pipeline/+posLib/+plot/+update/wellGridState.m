function wellGridState(instruction, t)
% Plot elements of positional grid (make grid elements appear and disappear)
%
% .gridTable table to sample grid regions from corresponding to state 
%   at the moment only supports gridTable of type struct
% .colors colorscheme for each block [B x 3]
% .state hot-encoding or integer vector that controls presence or absence of state blocks
% .label labels for each

state = instruction.state(t);
%filt = ismember(instruction.possibleStates, state);
%on_states  = instruction.possibleStates(filt);
%off_states = instruction.possibleStates(~filt);
%if any(on_states)
%    set(instruction.obj(on_states),'Visible','on');
%end
%if any(off_states)
%    set(instruction.obj(off_states),'Visible','off')
%end

% Initialized value
state = instruction.state(t, :);
if isfield(instruction,'thresh')
    state(state < instruction.thresh) = 0;
end
for g = 1:numel(state)
    set(instruction.obj(g), 'FaceAlpha', state(g), 'EdgeAlpha', state(g));
end
