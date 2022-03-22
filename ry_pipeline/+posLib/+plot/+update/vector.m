function L = vector(I, T)

% Vector plot
for i = 1:numel(T)
    t = T(i);
    set(I.obj(i),...
        'xdata', [I.x(t), I.x(t) + I.u(t)],...
        'ydata', [I.y(t), I.y(t) + I.v(t)]);
end
%if ~isempty(varargin)
%    set(L, varargin{:});
%end
