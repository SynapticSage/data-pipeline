function diotable(animID, dayepoch, varargin)
% GENERATEDIOTABLES uses maze and dio structures to create dio tables per epoch

if nargin < 2
    dayepoch = [];
end

% Alias
DIFFERENT = 0;
POSSIBLY_SAME = 1;
SAME = 2;

ip = inputParser;
ip.addParameter('assumeMazeFilesSame', POSSIBLY_SAME); % possibilities, 0: do not assume, 1: check/assume, 2: assume, no cheeck
ip.addParameter('homeFromeMode',    true); % whether to detect the home well from the mode of activated leds
ip.parse(varargin{:})
opt = ip.Results;

disp("Reading DIO files")
dioAll = ndBranch.load(animID, 'DIO', 'indices', dayepoch);
disp("Indexing DIO files")   
indicesDio  = ndBranch.indicesMatrixForm(dioAll);
disp("Reading maze files")   
mazeAll = ndBranch.load(animID, 'maze', 'indices', dayepoch)
disp("Indexing maze files")   
indicesMaze = ndBranch.indicesMatrixForm(mazeAll);
mazeAll = ndBranch.toNd(mazeAll);


% Static or dynamic use of maze files?
if opt.assumeMazeFilesSame == POSSIBLY_SAME
    disp('Checking if all maze files are equal...');
    M = mazeAll(:);
    M = M(~arrayfun(@nd.isEmpty, M));
    M = {M.dio}; % we only want to know if dio mappping stays const
    %M = num2cell(M);
    if numel(M) == 1 || isequal( M{:} )
        disp('...maze files are the same...')
        opt.assumeMazeFilesSame  = SAME;
    else
        disp('...maze files NOT the same...')
        opt.assumeMazeFilesSame  = DIFFERENT;
    end
end

% Compute indices to iterate through
if opt.assumeMazeFilesSame == SAME
    indices     = unique(indicesDio(:,1:2),'rows'); % Definitely have all files
else
    indices     = intersect(indicesMaze, unique(indicesDio(:,1:2),'rows'), 'rows'); % Unsure if have all maze files and will assume SAME
end

% Static maze file
first = num2cell(indicesMaze(1,1:2));
maze = mazeAll(first{:});

if ~isempty(dayepoch)
    m = min(size(dayepoch,2), size(indices,2));
    matches = ismember(indices(:,1:m), dayepoch(:,1:m),'rows');
    indices = indices(matches,:);
end

diotable = {};
prog = ProgressBar(size(indices,1), 'Title', 'Building diotable');
for index = indices'

    dio = ndBranch.get(dioAll, index);
    prog.printMessage("Processing " + sprintf('(%02d-%02d)',index));

    % Dynamic maze file
    if opt.assumeMazeFilesSame == DIFFERENT
        I = num2cell(index(1:2));
        maze = mazeAll(I{:});
    end

    % If no dio data, skip!
    dio = tidyData.fromNd(dio);
    if height(dio) == 0
        prog.printMessage("Skipping index [" + num2str(index') + "].")
        prog.step([],[],[])
        continue
    end
    
    % If home from statistical mode
    if opt.homeFromeMode
        prog.printMessage('Obtaining home region from mode of cue leds')
        dio = dioLib.tagDioWithCallback(dio);
        [maze.platform.home, maze.platform.arena] = dioLib.estimateHome(dio, maze);

    end
    dio = dio(~isnan(dio.num),:);
     % Tag dio information
    dio = dioLib.tagDioWithCallback(dio, maze);

    % Save diotable
    diotable = ndBranch.set(diotable, index', dio);
    prog.step([],[],[]);
end
ndBranch.save(diotable, animID, 'diotable', 1);
