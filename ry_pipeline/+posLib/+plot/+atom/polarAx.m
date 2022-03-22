function P = polarAx(ax, theta, r,  r0, varargin)
% polarVec plots a vector into a polar axis

if nargin < 4 || isempty(r0)
    r0 = 0;
end
if nargin < 3 || isempty(r)
    r = 1;
end
if numel(theta) == 1
   theta = [theta; theta];
end

P = polarplot(ax, theta, [r0; r]);
set(P,varargin{:});
