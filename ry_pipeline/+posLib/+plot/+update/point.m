function point(I, T)
% Point plot of animal position

for i = 1:numel(T)
    t= T(i);
    clearpoints(I.obj(i));
    addpoints(I.obj(i), I.x(t), I.y(t))
end
%if ~isempty(I.varargin)
%    set([I.obj], Ivarargin{:});
%end
