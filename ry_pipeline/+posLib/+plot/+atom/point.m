function P = point(I, T)
% Point plot of animal position

P = gobjects(numel(T),1);
for i = 1:numel(T)
    t = T(i);
    P(i) = animatedline(I.x(t), I.y(t));
end
if isfield(I,'varargin') && ~isempty(I.varargin)
    set(P, I.varargin{:});
end
if isfield(I,'VARMULT') && ~isempty(I.VARMULT)
    for i  = 1:size(Opt.VARMULT,1)
        set(P(i), Opt.VARMULT{i,:});
    end
end
