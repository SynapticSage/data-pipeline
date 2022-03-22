function copyDLCResultsToRawDir(dlcDirs, dayDirs)
% Copies results of deeplabcut to animal day directories
%
% Both parameters are lists (cellstr or string) of paths to deeplabcut
% directories and raw day directories to put results.

for dlcDir = string(dlcDirs)
for dayDir = string(dayDirs)
    tsFiles = dir(fullfile(dayDir,'*.videoTimeStamps'));
    tsFiles = string({tsFiles.name});
    basenames = arrayfun(@(tsFile) replace(tsFile, '.videoTimeStamps', ''), tsFiles, 'UniformOutput', true);
    for basename = basenames
        csvfiles = dir(fullfile(dlcDir, "videos", basename + "*.csv"));
        for i = 1:numel(csvfiles)
            name = csvfiles(i).name;
            path = csvfiles(i).folder;
            dlcFile =  dayDir + filesep + basename + ".dlc";
            if contains(name,'filtered')
                copyfile(fullfile(path,name), dlcFile + ".filtered" + ".csv");
            else
                copyfile(fullfile(path,name), dlcFile + ".csv");
            end
        end

    end
end
end
