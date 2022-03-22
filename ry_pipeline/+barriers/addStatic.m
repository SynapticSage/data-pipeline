function addStatic(animal, day, object_names, varargin)
% Annotates static barrier locations in day of recording
% 
% Optionally loads previous configurations from other days

ip = inputParser;
ip.addParameter('loadPrevious', false); % false | true | set of possible days/dayepochs
ip.parse(varargin{:})
Opt = ip.Results;

barrier_names = string(barrier_names);

% Struct location placed into
% ---------------------------
% task --> |
%          barriers (struct) -->
%                               |
%                               .object : rectangular or circular object representing it's shape, drawn by user
%                               .location : location properties in coordintes relative to the task boundaries
%                                           (these differ for circular or rectangular barriers)

% For each barrier or object in the maze, let's annotate
for object = object_names

end
