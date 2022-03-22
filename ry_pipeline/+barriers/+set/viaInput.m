function infoStruct = viaInput(animID, index, objectNames, varargin)
% User inputs an object location


ip = inputParser;
ip.addOptional('formerOutputArgs', {}, @iscell);
ip.addParameter('adaptimage', true);
ip.addParameter('posLimit',   [],    @isnumeric);
ip.addParameter('tryAverageOfSessions', [], @isnumeric);
ip.parse(varargin{:})
opt = ip.Results;

pos = ndb.load(animID, 'pos', 'index', index);
pos = cellfetch(animID, 'data');
pos = cat(1,pos.values{:});

fid = figure('Position', get(0,'ScreenSize'));
cleanup = onCleanup(@() close(fid));

% If adapt image, make it easier to see features
if opt.adaptimage
    % Adjust videoframe to be easy to see, regardless of lighting
    for i = 2:3
        videoframe(:,:,i) = adapthisteq(videoframe(:,:,i),'clipLimit',0.015,'Distribution','rayleigh');
    end
end

% Plot videoframe
if iscell(videoframe)
    image(videoframe{:});
else
    image(videoframe);
end

%  Plot position
if isempty(opt.posLimit) || size(pos,1) < opt.posLimit
    inds = 1:size(pos,1);
else
    inds=round(linspace(1, size(pos,1), opt.posLimit));
end
hold on
p = plot(pos(inds,2),pos(inds,3),'LineStyle','--', 'Color', 'red');
p.Color = [p.Color, 0.025];

% Use former output?
%Output = parseFormerOutput(opt.formerOutputArgs);
%if ~isempty(Output.coords)
%    boundary = Opt.boundary;
%    welllocs = Opt.welllocs;
%    [P,W] = plotMazeProperties(boundary, welllocs);
%    action = collectAction('null');
%    if ismember(action, ["n","s"])
%        delete(W);
%        delete(P);
%    end
%else
%    [boundary, welllocs] = deal([]);
%    action = string('n');
%end

% KEY LOOP
% --------
while action ~= "y"
    [x, y, action] = selectPoints(action, Output);
    Prop   = getMazeProperties(x,y);
    [P,W]  = plotMazeProperties(Prop);
    Prop   = parseFormerOutput(Prop);
    action = collectAction(action);
end

% ----------------------------------------------------------------------

    % (2) -----
    function Prop = getMazeProperties(Prop)

        % Place all propertes in structure
        Prop.TrackBoundary = copyobj(Prop.TrackBoundary);
        Prop.TrackBoundary.Parent = [];
        Prop.Wells = copyobj(Prop.Wells);
        Prop.Wells.Parent = [];
        Prop.Home = copyobj(Prop.TrackBoundary);
        Prop.Home.Position = Prop.Home.Position(5:end,:);
        Prop.Home.Label = 'Home';
        Prop.Arena = copyobj(Prop.TrackBoundary);
        Prop.Arena.Position = Prop.Arena.Position(1:4,:);
        Prop.Arena.Label = 'Arena';

    % (3) -----
    function [P, W] = plotMazeProperties(Prop)

        hold on;
        fields = string(fieldnames(Prop));
        for field = fields(:)'
            Prop.(field).Parent = gca;
        end

    % (1) -----
    function [x,y,newaction] = selectPoints(action, Output)

        switch char(action)
        case 'n' % new/no
            set(gca,'Visible','off')
            delete(findobj(gcf,'Type','Line'));
            delete(findobj(gcf,'Type','Scatter'));
            delete(findobj(gcf,'Type','Patch'));
            delete(findobj(gcf,'Type','images.roi.Polygon'));
            delete(findobj(gcf,'Type','images.roi.Circle'));
            try
                sgtitle('Click the 6 maze bound points in order', 'Color', [1, 0.5, 0], 'FontSize', 25)
                %[x,y] = ginputc(6, 'ShowPoints', true, 'ConnectPoints', true, 'LineStyle', ':');
                kws={'Label', "Maze boundary",'Color','white'};
                polygon = drawpolygon(kws{:});
                while size(polygon.Position,1) ~= 8
                    polygon = drawpolygon(kws{:});
                    delete(polygon);
                end
                sgtitle('Bound the 5 wells  in order', 'Color', [0.5, 0, 1], 'FontSize', 25)
                circles=[];
                for i = 1:5
                    circles(i) = drawcircle('Label',sprintf('Well %d', i), 'Color', 'Red', 'LabelVisible', 'off');
                    addlistener(point(i), 'ROIMoved', @(x,~) plotCenter(x));
                end
            catch
            end
            ROI.TrackBoundary = polygon;
            ROI.Wells = circles;
        case 's' % shift
            point_x = []; 
            point_y = [];
            title('Click only the first point');
            while isempty(point_x) && isempty(point_y)
                try
                    sgtitle('Click only the first point', 'Color', [1, 0.5, 0])
                    [point_x, point_y] = ginputc(1, 'ShowPoints', true);
                catch
                end
            end

        case  ''
            ROI = Output;
        otherwise
            error('action %s not understood', action);
        end
        newaction='null';

    function action = collectAction(currentAction)

        while currentAction~="n" && currentAction ~= "s" && currentAction~="y" ...
            && strlength(currentAction) ~= 0
            message = 'Press enter to accept. To shift by constant value: s. To do all coordinates: n. To accept, y. (default y):\n';
            action = input(message,'s');
            action = string(strip(action));
            if action == ""; action = "y"; end
            currentAction = action;
        end

        
    % (4) -----
    function Output = parseFormerOutput(input)

        ip = inputParser;
        ip.addParameter('boundary',[]);
        ip.addParameter('welllocs',[]);
        ip.parse(input{:})
        Output = ip.Results;
        if ~isempty(Output.boundary) && ~isempty(Output.welllocs)
            Output.coords = [Output.boundary(1:4,:); Output.boundary(6:7,:); Output.welllocs];
        else
            Output.coords = [];
        end

    function Circ = plotCenter(Circ)
        hold on;
        prev = findobj('Tag', 'CirclePoint');
        if ~isempty(prev)
            delete(prev)
        end
        p = plot(Circ.Center(1),Circ.Center(2), 'ro');
        p.Tag = 'CirclePoint';



    function roi = shift(roi)

        xDelta = (point_x - ROI.Wells(1).Center(1,1));
        yDelta = (point_y - ROI.Wells(1).Center(1,2));

        for i = 1:5
            ROI.Wells(i).Center = ROI.Wells(i).Center + [xDelta, yDelta];
        end
        ROI.Wells(i).TrackBoundary = ROI.Wells(i).Center + [xDelta, yDelta];


