function s = magnitudeAx(I, t)
% Creates a gauge in a separate figure axis

t = t(end);

ip = inputParser;
ip.KeepUnmatched
ip.addParameter('colormap', cmocean('thermal'));
ip.addParameter('orientation', 'horizontal');
ip.addParameter('position', 'bottom');
ip.parse(I.varargin{:})
Opt = ip.Results;

p = I.val(t)/I.maxval(t);

switch opt.orientation
case 'vertical'
    x = [0.5 1 1.5] ;
    y = linspace(0,100) ;
    y(y>p*100 & y<100) = nan ;
case  'horizontal'
    y = [0.5 1 1.5] ;
    x = linspace(0,100) ;
    x(x>p*100 & x<100) = nan ;
end

[x,y] = meshgrid(x,y) ;
z = x+y ;

axes(I.ax);
s= surf(x,y,z);
colormap(jet);
shading interp;
view(2)

set(s,I.varargin{:})
