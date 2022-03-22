function recOrder = ry_generateRecOrder(animalRawDir, dayDirs, varargin)
% If your recfiles are alphabetically ordered in each directory, this outputs that order.

% Optional Argument
% -----------------
ip = inputParser;
ip.addParameter('exclusions', []); % session folders to exclude
ip.addParameter('skipNonexist', false); % session folders to exclude
ip.parse(varargin{:});
opt = ip.Results;

currdir = pwd;
destructor = onCleanup(@() cd(currdir));

animalRawDir = string(animalRawDir);
dayDirs = string(dayDirs);

recOrder = cell(numel(dayDirs),1);
iDay = 1;
for dayDir = dayDirs
    
    folder = join([animalRawDir, dayDir], filesep);

    if exist(folder,'dir')

        [recFiles, dirs] = searchFolder(folder);

        %if startsWith(dayDir, '21_'); keyboard; end
        recFilesFound = ~isempty(recFiles);
        if ~recFilesFound
            clear recFiles
            dcount = 0;
            for d = dirs
                dcount =  dcount + 1;
                [r, ~] = searchFolder(d); 
                recFiles{dcount} = r;
            end
            recFiles = cat(2, recFiles{:});
            recFiles = recFiles(:);
            recFilesFound = ~isempty(recFiles);
        end

        if ~recFilesFound 
            if opt.skipNonexist
                warning('Missing files for %s', folder);
            else 
                error('Recfiles not found for %s', folder)
            end
        else
            recOrder{iDay} = cellstr(recFiles);
        end

    elseif opt.skipNonexist
        warning('Missing files for %s', folder);
    else
        error('Missing files for %s', folder);
    end

    iDay = iDay+1;
end


function [recFiles, dirs] = searchFolder(folder)

        destructor = onCleanup(@popd);
        pushd(folder);

        files = dir();

        % Rec Files
        filenames = string({files.name});
        dirnames = string({files.folder});
        recFiles = dirnames + filesep + filenames;
        recFiles = recFiles(endsWith(recFiles,".rec"));
        recFiles = sort(recFiles);

        % Directories
        dirs = files([files.isdir] & string({files.name}) ~= ".");
        dirs = string({dirs.folder}) + filesep + string({dirs.name});
        dirs = dirs(:)';
