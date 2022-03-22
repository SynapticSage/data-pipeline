function updateToNewerOrganization(dayFolders)
% Newer trodes stores each recording in its own folder. Older style was to
% place all of the files, the rec and its connected video/dio files, in one
% folder for all of a day's recording.
%
% This file updates an older style to a newer style

parentdir = pwd;
destructorParent = onCleanup(@() cd(parentdir));

if numel(dayFolders) > 1
    for i = progress(1:numel(dayFolders), 'Title', 'Updating')
        dirLib.rec.updateToNewerOrganization(dayFolders(i));
    end
else
    
    currdir = pwd;
    destructorSingle= onCleanup(@() cd(currdir));

    cd(dayFolders); % dir() command somehow climbs out one folder?
    recfiles = dir('*.rec');
    
    epochMatch = strrep(string({recfiles.name}),'.rec','');
    for epoch = epochMatch

        if ~exist(epoch, 'dir')
            epochFolder = string(pwd) + filesep + epoch;
            disp("Making folder " + epochFolder);
            mkdir(epochFolder);
        end

        files_to_move = dir(epoch + '.*');
        initial = string({files_to_move.folder}) + filesep + {files_to_move.name};
        final   = string(pwd) + filesep + epoch + filesep + {files_to_move.name};

        for f = 1:numel(initial)
            disp("Moving file " + initial(f) + " to " + final(f));
            movefile(initial(f), final(f));
        end

    end
end


