function T = cellsFromJSON(animal, index, varargin)
% extracts json props of mountainsort for putative cells
%
% animal : str/char
%   name of the animal
% index : list of integers or empty []
%   which day, which epoch to check
%   if empty [], check all available
%
%   OPtionals
%
% can be curated if you just add 'type', 'curated' name-value pairs
% default is 'raw'

ip = inputParser;
ip.addParameter('type', 'raw');
ip.parse(varargin{:})
Opt = ip.Results;

% Find all of the mda files
Info = animalinfo(animal);
jsonSuperFolder = fullfile(Info.directDir, 'MountainSort');
if ~isempty(index)
    if numel(index) == 1
        dayFolders = string(sprintf('%s_%02d.mountain', animal, index));
    else
        error("index with numel=" + numel(index) + " not implemented");
    end
else
    dayFolders = dir(fullfile(jsonSuperFolder, '*_*.mountain'));
    dayFolders = dayFolders([dayFolders.isdir]);
    dayFolders = string({dayFolders.name});
end

T = {};
for dayFolder = progress(dayFolders, 'Title', 'Checking days')
    day = dayFolder.extractAfter(animal + "_").extractBefore(".mountain");
    day = str2double(day);

    tetFolders = dir(fullfile(jsonSuperFolder, dayFolder));
    tetFolders = tetFolders([tetFolders.isdir]);
    tetFolders = string({tetFolders.name});
    tetFolders = tetFolders(~ismember(tetFolders, [".",".."]));
    for tetFolder = progress(tetFolders, 'Title', 'Checking tetrodes')
        tet = tetFolder.extractBefore(".mountain").extractAfter(animal + "_" + day);
        tet = str2double(tet.extractAfter(".nt"));

        json = dir(fullfile(jsonSuperFolder, dayFolder, tetFolder, sprintf('metrics_%s.json', Opt.type)));
        if ~isempty(json)
            jsonfile = fullfile(json(1). folder, json(1).name);
            json = loadjson(jsonfile);
            T{end+1} = extractTableEntry(json, 'day', day, 'tet', tet);
        end
    end
    
end
T = cat(1, T{:});

% post process properties
T = sortrows(T, ["day","tet","tetcellid"]);

% within each day setup a unique cell identifier .. not guarenteed to match the cell ids of other methods
for day = unique(T.day)'
    t = T(T.day == day,:);
    t.cell = findgroups(t.tet, t.tetcellid);
    T(T.day == day,:) = t;
end

function t = extractTableEntry(json, varargin)
   
    clusters = cat(1,json.clusters{:});
    t = cell(numel(clusters), 1);
    tcnt = 0;
    for cluster = clusters(:)'
        tcnt = tcnt + 1;
        tmp = struct2table(cluster.metrics);
        tmp.tetcellid = cluster.label;
        for v = 1:2:numel(varargin)
            tmp.(varargin{v}) = varargin{v+1};
        end
        t{tcnt} = tmp;
    end
    t = cat(1, t{:});

