function correctRecFolderStructure(animal)
% Convenience function that brings an animal's folder structure into alignment
% with the style of folder our pipeline expects. Not how Trodes currently
% save it.

ainfo = animalinfo(animal);
currDir = pwd;
destructor = onCleanup(@() cd(currDir));

cd(ainfo.rawDir);
dayFolders = dir('*_*');

for file = dayFolders(:)'
    dayDir = fullfile(file.folder, file.name);
    if file.isdir && dirLib.rec.isNewOrganization(dayDir);
        disp("Correcting " + dayDir); 
        dirLib.rec.revertToOlderOrganization(dayDir);
    end
end
