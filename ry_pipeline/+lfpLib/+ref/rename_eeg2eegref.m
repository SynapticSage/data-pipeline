function rename_eeg2eegref(animal, dayepoch)
%

files = ndbFile.files([string(animal), "eeg"], dayepoch);
for file = files(:)'
    newname = replace(file.name, 'eeg','eegref');
    movefile(fullfile(file.folder, file.name), ...
             fullfile(file.folder, newname));
end

