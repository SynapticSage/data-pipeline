function gridTable = generatePositionGrid(task,varargin)
% generates a grid of positions for the maze for home section and the arena

ip = inputParser;
ip.addParameter('avoidWells', true);
ip.addParameter('perDay',true); % Generate  only one grid per day?
ip.addParameter('dayepoch',[]); % can be used for day epoch labels if those do not correspond to index positions of task structs. 
ip.addParameter('wellRadius', 8); % Centimeter radius
ip.addParameter('cmBeyondWalls', 8); % How many cm to sample beyond the walls
ip.addParameter('wellDetection', 'whole'); % whole | center
ip.addParameter('replaceGridWellZomeWithSpecific',true);
ip.addParameter('grid', [8]); % cm spacing
ip.parse(varargin{:})
Opt = ip.Results;

if iscell(task)
    indices = ndb.indicesMatrixForm(task);
    TASK = ndb.toNd(task);
else
    indices = nd.indicesMatrixForm(task);
    TASK = task;
end
filt = [TASK.type] == "run";
indices = indices(filt,:);

if Opt.perDay && numel(task) > 1
    dayDiff = [1; diff(indices(:,1))];
    indices = indices(dayDiff >= 1,:);
end

gridTable = table();
labels = ndbFile.datatypeLevels('task');
cnt = 0;
for index = progress(indices','Title','Creating position grids')

    I = num2cell(index);
    task = TASK(I{:});
    t = table();

    if ~isfield(task,'maze') || ~isfield(task.maze,'homeBoundary')
        continue
    end

    % Get boundaries of the environment
    % ---------------------------------
    if isequal(task.maze.units, 'px')
        cmperpix = task.video.cmperpixel;
        home     = task.maze.homeBoundary  * cmperpix;
        arena    = task.maze.arenaBoundary * cmperpix;
        welllocs = task.maze.welllocs      * cmperpix;
    elseif isequal(task.maze.units, 'cm')
        home  = task.maze.homeBoundary;
        arena = task.maze.arenaBoundary;
        welllocs = task.maze.welllocs ;
    else
        error("Unit not recognized");
    end


    % Obtain an overall grid
    % ----------------------
    % X X Y Y
    home_bound    = [min(home(:,  1)), max(home(:,  1)), min(home(:,  2)), max(home(:,  2))]; % x X y Y
    arena_bound   = [min(arena(:, 1)), max(arena(:, 1)), min(arena(:, 2)), max(arena(:, 2))];
    bound         = [home_bound; arena_bound];
    overall_bound = [min(bound(:,1)), max(bound(:,2)), min(bound(:,3)), max(bound(:,4))];
    if Opt.cmBeyondWalls
        C = Opt.cmBeyondWalls;
        overall_bound = [overall_bound; ...
                         overall_bound + [-C,C,-C,C]];
    end

    % Lets make the grid fit our grid-size discretization (some equal number of
    % those units)
    %cmSize = [range(bound(end,1:2)), range(bound(end,3:4))]; % X 
    %chunks = cmSize / Opt.grid;
    %chunks = ceil(chunks);
    %newbound_min = [overall_bound(1), overall_bound(3)]; % x y
    %newbound_max = newbound_min + chunks.*Opt.grid;      % X Y
    %center_new = mean([newbound_max;newbound_min]);
    %center_old = mean([overall_bound(end,[1,3]);overall_bound(end,[2,4])]); % 
    %delta = center_old - center_new;
    %newbound = [newbound_min + delta; newbound_max + delta];
    %newbound = newbound(:)';
    %overall_bound(end+1,:) = newbound;

    % Create a grid
    % --------------
    % center_x, center_y, left, right, up, down, 
    boxSide = Opt.grid;
    leftright = overall_bound(end,1): boxSide : overall_bound(end,2);
    downup    = overall_bound(end,3): boxSide : overall_bound(end,4);
    left  = leftright(1:end-1);
    right = leftright(2:end);
    down  = downup(1:end-1);
    up    = downup(2:end);
    [left,up]    = meshgrid(left,up);
    [right,down] = meshgrid(right,down);
    left = left(:);
    right = right(:);
    down = down(:);
    up = up(:);
    center_x = mean([left, right]');
    center_y = mean([down, up]');
    
    % Add to table
    t.center_x = center_x(:);
    t.center_y = center_y(:);
    t.left     = left(:);
    t.right    = right(:);
    t.down     = down(:);
    t.up       = up(:);

    % Classify boxes by identity
    % --------------------------
    % region, well, wellZone
    homeAssign  = inpolygon(center_x', center_y', home(:,  1), home(:,  2));
    arenaAssign = inpolygon(center_x', center_y', arena(:, 1), arena(:, 2));
    region = repmat("outer", size(center_x));
    region(logical(homeAssign))  = "home";
    region(logical(arenaAssign)) = "arena";
    % create polygons to do well detection per square region
    for i =  1:size(left,1)
        for j  =  1:size(welllocs,1)
            loc(i,j) =  inpolygon(welllocs(j,1)', welllocs(j,2)', ...
                [left(i),right(i),right(i),left(i)],...
                [down(i),down(i),up(i),up(i)]);
        end
    end
    [locations, W] =  find(loc);
    wells  = zeros(size(loc,1),1);
    wells(locations) = W;
    % finally let's detect the squares who are at least partially in the zone
    % of the reward wells
    R =  Opt.wellRadius;
    wellZone = zeros(size(left,1),size(welllocs,1));
    for i =  1:size(left,1)
        for j  =  1:size(welllocs,1)
            well = welllocs(j,:);
            switch Opt.wellDetection
                case 'whole'
                    X  = [left(i),right(i),right(i),left(i)];
                    Y  = [down(i),down(i),up(i),up(i)];
                case 'center'
                    X  = center_x(i);
                    Y  = center_y(i);
            end
            tmp = X < well(1)+R & X > well(1)-R & ...
                  Y < well(2)+R & Y > well(2)-R;
            wellZone(i,j) = any(tmp);
        end
    end
    wellZone = any(wellZone,2);

    % Add to table
    t.region   = region(:);
    t.well     = wells(:);
    t.wellZone = wellZone(:);

    if Opt.replaceGridWellZomeWithSpecific
        disp("Clearing well zone and populating with precise well locationos")
        t(t.wellZone==true,:) = [];
        for i = size(welllocs,1):-1:1
            w = table();
            w.center_x = welllocs(i,1);
            w.center_y = welllocs(i,2);
            w.left  = w.center_x - boxSide/2;
            w.right = w.center_x + boxSide/2;
            w.down = w.center_y - boxSide/2;
            w.up   = w.center_y + boxSide/2;
            w.wellZone = 1;
            w.well = i;
            if inpolygon(w.center_x,w.center_y,home(:,1),home(:,2))
                w.region = "home";
            else
                w.region = "arena";
            end
            t = [w; t];
        end
    end
    I = 1:height(t);
    t.index    = I(:);
    if Opt.dayepoch
        index = dayepoch(cnt,:);
        cnt = cnt+1;
    end
    t.day  = repmat(index(1),height(t),1);
    if ~Opt.perDay
        t.epoch  = repmat(index(2),height(t),1);
    end

    gridTable = [gridTable;t];
end
