function magnitude(m, val, maxval, varargin);

ip = inputParser;
ip.KeepUnmatched = true;
ip.addParameter('orientation', 'horizontal');
ip.addParameter('position', 'bottom');
ip.parse(varargin{:})
Opt = ip.Results;

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

set(m, 'XData', x, 'YData', y);
