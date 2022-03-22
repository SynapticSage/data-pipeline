function [L,T] = vector(I, T)
% Vector plot
L = gobjects(numel(T),1);
for i = 1:numel(T)
    t = T(i);
    L(i) = line([I.x(t), I.x(t) + I.u(t)], [I.y(t), I.y(t)+I.v(t)]);
end

if ~isempty(I.varargin)
    set(L, I.varargin{:});
end

if isfield(I,'VARMULT') && ~isempty(I.VARMULT)
    for i = 1:size(VARMULT,1)
        set(L(i), Opt.VARMULT{i,:});
    end
end

if isfield(I,'labels') && ~isempty(I.labels)
else
    T = [];
end
