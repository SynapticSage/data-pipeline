function polarVec(p, theta, r, r0, varargin)


if nargin < 4 || isempty(r0)
    r0 = 0;
end
if nargin < 3  || isempty(r)
    r = 1;
end
if numel(theta) == 1
   theta = [theta; theta];
end
R = [r0; r];

set(p, 'RData', R, 'ThetaData', theta);
