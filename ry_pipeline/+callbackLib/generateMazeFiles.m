function generateMazeFiles(animID, dataDir, varargin)
% Generates ANIMmaze%02d files that describe what functions the computer recorded for each of the DIO ports in the maze.
% Dependencies: +branch library

ip  = inputParser;
ip.addParameter('orderingFields', []);
ip.addParameter('nameRemapping', []);
ip.addParameter('deleteFields', []);
ip.addParameter('regionLabels', []);
ip.parse(varargin{:})
opt = ip.Results;

currdir = pwd;
cleaup = onCleanup(@() cd(currdir));

if nargin == 1
    dataDir = animaldef(animID);
    dataDir = dataDir{2};
end
    
cd(dataDir);

% Load callback data 
ndBranch.load(animID, 'callback', ...
    'asNd', false,... as nd struct instead of branched cell
    'folderIsRelative', true,...
    'folder', 'callback');

% Extract the maze substructure
maze = {};
indices = ndBranch.indicesMatrixForm(callback);
for index = indices'
    C = ndBranch.get(callback, index);

    if ~nd.isEmpty(C.maze)
        C.maze = transform(C.maze, opt);
    end
    maze = ndBranch.set(maze, index, C.maze);
end

% Save back to animal folder
ndBranch.save(maze, animID, 'maze', 0)

function X = transform(X, opt)

% Delete fields
for field  = string(opt.deleteFields)
    X = rmfield(X, field);
end
% Name remapping
for fields  = string(opt.nameRemapping)'
    X.(fields(2)) = X.(fields(1));
    X = rmfield(X, fields(1));
end
% Set aside ordering fields
for field = string(opt.orderingFields)
    X.ordering.(field) = X.(field);
    X = rmfield(X, field);
end
% Set aside region labels
for field = string(opt.regionLabels)
    X.region.(field) = X.(field);
    X = rmfield(X, field);
end
% Set aside dio labels
dioLabels = setdiff(string(fieldnames(X))', ["ordering","region"]);
for field = dioLabels
    X.dio.(field) = X.(field);
    X = rmfield(X, field);
end
