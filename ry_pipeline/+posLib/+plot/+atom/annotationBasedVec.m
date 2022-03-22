function [an] = vecAnnot(x, y, txt, color)

if isscalar(x)
    x=[0 x];
end
if isscalar(y)
    y=[0  y];
end

%quiver(0,0,x,y);

[X, Y] = util.fig.data2figpos(x, y');
an = annotation('textarrow', X, Y, 'String', txt, 'Color', color);
