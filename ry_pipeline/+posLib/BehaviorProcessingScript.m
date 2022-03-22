for day = progress(33:35, 'Title','Days of egocentric')

    %fprintf('PreProcessing %s Day %02i...\n',animID,day);
    %dayDir = fullfile(rawDir, dayDirs{day}); 
    %% Checksum 
    %[validation, validationTable] = ry_validateAndFixFolder(dayDir);
    %if ~validation % checks if folder has one *.stateScriptLog per epoch and if each trodesComment for each epoch only one start and one stop
    %    disp(validationTable)
    %end
    %ry_deeplabcut.createNQRawPosFiles(dayDir, dataDir,  animID, day,...
    %                                'tableOutputDir', fullfile(dataDir,'deepinsight'),...
    %                                'cmPerPixel', cmperpix)
    disp("Day " + day);
    %if day ~= 36
    %    ry_deeplabcut.createNQPosFiles(dayDir, dataDir, animID, day);
    %    trialLib.create.events(animID, day);
    %    trialLib.create.traj(animID,   day);
    %end
    %posLib.create.goalPos(animID, day);

    %for setname = {'deepinsightUnfilt', 'deepinsight'}
    %    %rawLib.create.deepinsightRaw(dayDir, animID, day,...
    %    %    'transpose', true, 'dataname', setname{1}, 'folderGlob', '*.rawmda','epochfilt', [4 5 7]);
    %    %rawLib.append.metadata(dayDir, animID, day,...
    %    %    'transpose', true, 'dataname', setname{1}, 'folderGlob', '*.rawmda','epochfilt', [4 5 7]);
    %    rawLib.append.behavior(animID, [36 4; 36 5; 36 7], 'egocentric', [],...
    %        'changefield', {'time','postime'},...
    %        'dataname', setname{1},...
    %        'transpose',   true);
    %end
    %rawLib.mod.transpose(animID, day, [],'dataname', 'deepinsightUnfilt'); % Later realized that dimensions invert when python loads HDF ... this step accounts for that.
    
    disp("Loading day " + day + " behavior");
    behavior = ndb.load(animal, 'behavior', 'inds', day);
    inds = ndb.indicesMatrixForm(behavior);
    for ind = inds'
        disp("Modifying day " + day + " behavior");
        e = ndb.get(behavior, ind);
        e.poke = posLib.poke.getMatrix(animal, ind(:)', e.postime, "input", "poke");
        e.milk = posLib.poke.getMatrix(animal, ind(:)', e.postime, "output", "reward");
        behavior = ndb.set(behavior, ind, e);
    end
    ndb.save(behavior, animal, 'behavior', 1);

end
