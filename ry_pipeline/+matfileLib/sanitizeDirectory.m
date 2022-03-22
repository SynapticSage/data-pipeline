function sanitizeDirectory(mfile_directory)
% directory version of sanitize_matfile
% iterates over the callback files in the
% directory and autosanitizes

cdir = pwd;
cd(mfile_directory)

% Get list of callback files
callbacks = dir('*callback_state*');
% Iterate each one and sanitize it
for file = progress(callbacks')
    if ~contains(file.name, 'callback') continue; end
    disp(['Processing ' file.name]);
    matfileLib.sanitizeFile(file.name);
end

cd(cdir);
