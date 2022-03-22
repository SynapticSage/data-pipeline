function positionGridState(instruction, t)
    % Plot elements of positional grid (make grid elements appear and disappear)
    %
    % .gridTable table to sample grid regions from corresponding to state 
    %   at the moment only supports gridTable of type struct
    % .color colorscheme for each block [B x 3]
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
position_lambda_rect = @(x) x(t, 1:2);
position_lambda_circ = @(x, h, w) [x(t, 2:-1:1) + [w, h], w, h] ;

if isfield(instruction,'thresh')
    state(state < instruction.thresh) = 0;
end

if instruction.shape == "circle"
    circle = true;
else
    circle = false;
end

for g = 1:numel(state)
    if circle
        position = position_lambda_circ(instruction.position(t,g));
        kws = {'Center', position};
    else
        position = position_lambda_rect(instruction.position(t,g), instruction.height(t,g), instruction.width(t,g));
        kws = {'Position', position};
    end
    set(instruction.obj(g), 'FaceAlpha', state(g), 'EdgeAlpha', state(g), kws{:});
end

