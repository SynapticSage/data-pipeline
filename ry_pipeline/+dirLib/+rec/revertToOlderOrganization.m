function revertToOlderOrganization(dayFolders)
% Newer trodes stores each recording in its own folder. Older style was to
% place all of the files, the rec and its connected video/dio files, in one
% folder for all of a day's recording.
%
% Since our pipeline was hard-coded with this in mind, this sets an older organization from a newer organization

parentdir = pwd;
destructorParent = onCleanup(@() cd(parentdir));

if iscellstr(dayFolders) || ischar(dayFolders)
    dayFolders = string(dayFolders);
end

if numel(dayFolders) > 1
    answers = dirLib.rec.isNewOrganization(dayFolders);
    dayFolders = dayFolders(answers);
    for i = progress(1:numel(dayFolders),'Title','Reverting')
        dirLib.rec.revertToOlderOrganization(dayFolders(i));
    end
else
    
    currdir = pwd;
    destructorSingle= onCleanup(@() cd(currdir));

    cd(dayFolders);

    recfiles = dir('**/*.rec');
    cd(dayFolders); % dir() command somehow climbs out one folder?
    
    epochFolders = strrep(string({recfiles.name}),'.rec','');
    for name = epochFolders

        files_to_move = dir(name + filesep);
        files_to_move = files_to_move(~ismember(string({files_to_move.name}), ["..", "."]));
        initial = string({files_to_move.folder}) + filesep + {files_to_move.name};
        final = string(pwd) + filesep + {files_to_move.name};

        for f = 1:numel(initial)
            disp("Moving file " + initial(f) + " to " + final(f));
            movefile(initial(f), final(f));
        end
        cd(dayFolders); % dir() command somehow climbs out one folder?
        epochFolder = string(pwd) + filesep + name;
        if exist(epochFolder, 'dir')
            disp("Removing epoch folder: " + epochFolder);
            rmdir(epochFolder);
        end
    end
end

