function folders = mountainsort(animal, index, varargin)


ip = inputParser;
ip.addParameter('replace', {}); % string
ip.KeepUnmatched = true;
ip.parse(varargin{:})
Opt = ip.Results;


msfolder = dirLib.mountainsort(animal, index, Opt);
folders = dir(msfolder);
folders = string({folders.name});
folders = folders(contains(folders, '.nt'));
folders = fullfile(msfolder, folders);

folders = replace(folders, Opt.replace{:});
