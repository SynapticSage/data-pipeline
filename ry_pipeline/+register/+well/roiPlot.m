function axs = wellRoiPlot(axs, rects, frame, varargin)
% Takes a video frame and set of rectangular crop regions to plot
% for a video

ip = inputParser;
ip.addParameter('wellloc', []);
ip.addParameter('radius', []);
ip.addParameter('cmx', []);
ip.addParameter('cmy', []);
ip.addParameter('wholeFrame',true);
ip.parse(varargin{:});
Opt = ip.Results;

% Get CMax?
if ~isempty(Opt.cmx)
    x = opt.cmx;
else
    x = 1:size(frame,2);
end
if ~isempty(Opt.cmy)
    x = opt.cmy
else
    y = 1:size(frame,1);
end
[X, Y] = meshgrid(x,y);
if isempty(axs)
    if Opt.wholeFrame
        W = 6;
    else
        W = 1;
    end
    H = size(rects,1);
    for i = 1:size(rects,1)
        subplot(H,W,sub2ind([W H], 1, i));
        tmp = gca;
        axs(i) = tmp;
    end
    if Opt.wholeFrame
        subplot(H,W,sub2ind([W H], 2:W, 1:5));
        axs(end+1)=gca;
    end
end
assert(~isempty(axs))

% Subset the frames and show them in the given axes
wellim = [];
nWells = size(rects,1);
for w = 1:nWells
    wellim = imcrop(frame, rects(w,:));
    x = imcrop(X, rects(w,:));
    y = imcrop(Y, rects(w,:));
    x = x(1,:);
    y = y(:,1);
    axes(axs(w));
    image(x, y, wellim);
    if ~isempty(Opt.wellloc)
        hold on;
        scatter(wellloc(w,1), wellloc(w,2), 18, 'ro');
    end
    if ~isempty(Opt.radius)
    end

end
if Opt.wholeFrame
    %disp('got here')
    axes(axs(nWells+1));
    image(X(1,:),Y(:,1),frame)
    set(gca,'Visible','off')
    hold on
    for w = 1:nWells
        [V,F] = getVertices(rects(w,:));
        r=patch(gca, 'Vertices', V, 'Faces', F);
        set(r,'FaceAlpha',0.5,'FaceColor','white','EdgeColor','red','LineWidth',2, 'EdgeAlpha',0.5, 'Linestyle',':')
    end
end

function [V,F] = getVertices(rect)
    V(1,:) = rect(:,1:2);
    V(2,:) = V(1,:) + [rect(:,3),0];
    V(3,:) = V(2,:) + [0,rect(:,4)];
    V(4,:) = V(3,:) - [rect(:,3),0];
    F = [1 2 3 4];
