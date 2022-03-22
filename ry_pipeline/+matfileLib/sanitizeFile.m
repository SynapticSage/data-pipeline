function sanitizeFile(mfile)
% sanitize_matfile removes gui data from goalmaze matfiles
%
% Input
% -----
% mfile : char array
%   Name of the matfile to santize
% 
% Output
% ------
% void

% To avoid gui windows popping up,
set(0,'DefaultFigureVisible','off')

try
    % Saving in the maze callback apparently saved tones object mid or right
    % before desctructor called
    util.matfile.rmvar(mfile, 'tones');
end

% We will fake the GUI code to trick matlab into not looking for gui variables as I open the mat-file
fake_gui_file = 'GoalmazeControlLayout.m';
if ~exist('./GoalmazeControlLayout', 'file')
    fid = fopen(fake_gui_file, 'w');
    fwrite(fid, 'function GoalmazeControlLayout(varargin)');
    fclose(fid);
end

% Index into a matfile writably
mfile = matfile(mfile, 'Writable', true);

const = mfile.const;                            % pull out the const struct
if isfield(const, 'guiHandle')                  % If guiHandle in the structure
    const = rmfield(const, 'guiHandle');        % remove the gui handle
    disp('guiHandle found and removed');
end
if isfield(const, 'guiHandle_reward')           % If guiHandle_reward in the structure
    const = rmfield(const, 'guiHandle_reward'); % remove the gui handle
    disp('guiHandle_reward found and removed');
end
mfile.const = const;                            % overwrite the sanitized const struct

% close the file index object
clear m

% Delete the fake gui file
delete(fake_gui_file);

% Unset the figure invisibility
set(0,'DefaultFigureVisible','on')

