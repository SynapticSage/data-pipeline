function folder = mountainsort(animal, index, varargin)
% Returns the mountainsort directory used
%
ip = inputParser;
ip.addParameter('replace', {}); % string
ip.KeepUnmatched = true;
ip.parse(varargin{:})
Opt = ip.Results;

ainfo  = animaldef(animal);
folder = ainfo{2};
folder = fullfile(folder, 'MountainSort', sprintf('%s_%02d.mountain', animal, index));

Opt.replace = cellstr(Opt.replace);
folder = replace(folder, Opt.replace{:});
