function [out, curraw] = convert_ml_to_FF_withMultiunitAndMarks(animID,resDir,sessionNum,varargin)
% Convert mountainsort curated spikes to filter framework spikes files
% animID : animal ID
% resDir : mountainlab results directory for a single day
% sessionNum: number of day
% NAME-VALUE Pairs:
% samplerate : sampling rate in Hz, default 30000
% min_epoch_break : minumum recording time break to classify an epoch, 1 sec default
% overwrite : 1 or 0 (default), whether to overwrite an existing spikes file
%
% Ryan -- Modified convert_ml_to_FF.m to export marks.mat for an animal
%           FrankLab uses ANIMALmarks.mat for unclustered decodes
%           They can also be used to compute other metrics and to check
%           for the existence of tuning curves to properties, pre-clustering.
%         
%         if curated firings do not exist but raw firings do, 
%         creates a marks for that tet folder with raw mountainsort
%         parsed clusters
%
%
% ------------------------
% Parse optional arguments
% ------------------------
samplerate = 30000;
min_epoch_break=1;
overwrite = 0;
tagIgnore = ["artifact", "rejected", "noise"]; % tags to ignore
keepMarkClusterSeparate    = false; % Keep marks separated by cluster
keepMarkClusterInformation = true; % Whether to keep a 5th column for the cluster identity
processmarks     = true;
processspikes    = true;
processmultiunit = true;
keyboard_on_notag = true;
%tet_options = []; not used for now
assignVars(varargin)

% ------------------
% Directory foreplay
% ------------------
out = '';
tetDirs = dir([resDir filesep '*.mountain']);
timeFile = dir([resDir filesep '*timestamps*']);
if isempty(timeFile)
    error('No timestamps file found in %s',resDir);
end
timeFile = [timeFile.folder filesep timeFile.name];
if strcmp(timeFile(end-2:end),'prv')
    tmp = jsondecode(fileread(timeFile));
    timeFile = tmp.original_path;
end
timeDat = readmda(timeFile);
saveFile          = fullfile(resDir, '..', '..', sprintf('%sspikes%02i.mat',animID,sessionNum));
multiunitSaveFile = fullfile(resDir, '..', '..', sprintf('%smultiunit%02i.mat',animID,sessionNum));
markSaveFile      = fullfile(resDir, '..', '..', sprintf('%smarks%02i.mat',animID,sessionNum));
taskFile          = fullfile(resDir, '..', '..', sprintf('%stask%02i.mat',animID,sessionNum));
%spikeMarkSaveFile = fullfile(resDir, '..', '..', sprintf('%sspikeMarks%02i.mat',animID,sessionNum));

% -----------------------------------------------------------------
% Determine epoch start times by looking for gaps longer than 1 sec
% -----------------------------------------------------------------
if exist(taskFile,'file')
    disp("Using task file for epoch");
    task = ndb.load(animID, 'task', 'ind', sessionNum);
    task = ndb.toNd(task{sessionNum});
    Nepochs  = size(task, 1);
    epoch_starts = nd.fieldGet(task, 'starttime') * samplerate;
else
    disp("Computing epochs without the task file (ryan encountered a bug with this default mode once)");
    gaps = diff(timeDat);
    epoch_gaps = find(gaps>=min_epoch_break*samplerate);
    epoch_starts = timeDat([1 epoch_gaps]);
    Nepochs = numel(epoch_starts);
    fprintf('Detected %i epochs. Start times:\n',Nepochs);
    disp(epoch_starts');
end

% ---------------
% get tet numbers
% ---------------
pat = '\w*.nt(?<tet>[0-9]+).\w*';
parsed = cellfun(@(x) regexp(x,pat,'names'),{tetDirs.name},'UniformOutput',true);
tet_nums = str2double({parsed.tet});
Ntets = max(tet_nums);
fprintf('Detected %i tetrodes. Tetrodes:\n',Ntets);
disp(tet_nums');
drawnow;

%% --------------------
%% INTIALIZE STRUCTURES
%% --------------------
% Initialize spikes struct
spikes = cell(1,sessionNum);
spikes{sessionNum} = cell(1,Nepochs);
spikes{sessionNum}(:) = {cell(1,Ntets)};
% Initialize multiunit struct
multiunit = cell(1,sessionNum);
multiunit{sessionNum} = cell(1,Nepochs);
multiunit{sessionNum}(:) = {cell(1,Ntets)};
% Initialize marks struct
marks = cell(1,sessionNum);
marks{sessionNum} = cell(1,Nepochs);
marks{sessionNum}(:) = {cell(1,Ntets)};


%% ------------------------------------------------------------
%% FIRING 
%% ------------------------------------------------------------
% Process curated and uncurated firing!
if (processspikes || processmultiunit) && ...
   ( ~exist(saveFile, 'file') || ~exist(multiunitSaveFile, 'file') || overwrite)

    curraw = [0, 0, 0];
    for k=progress(1:numel(tetDirs), 'Title', 'Firings: processing tetrode direcetories')

        tD = [tetDirs(k).folder filesep tetDirs(k).name];
        tetNum = tet_nums(k);
        if exist([tD filesep 'metrics_curated.json'], 'file')
            metFile = [tD filesep 'metrics_curated.json'];
        elseif exist([tD filesep 'metrics_tagged.json'], 'file')
            metFile = [tD filesep 'metrics_tagged.json'];
        else
            warning('no metrics')
            if keyboard_on_notag
                keyboard
            end
        end

        paramsFile = [tD filesep 'params.json'];
        if exist(paramsFile,'file')
            params = jsondecode(fileread(paramsFile));
            if params.samplerate ~= samplerate
                error('Varargin samplerate must match samplingrate in params.json');
            end
        end

        curatedFireFile = [tD filesep 'firings.curated.mda'];
        rawFireFile     = [tD filesep 'firings_raw.mda'];
        marksFile       = [tD filesep 'marks.mda'];
        if isfile(curatedFireFile) 
            curraw(1) = curraw(1) + 1;
            fireFile = curatedFireFile;
            firingType = "curated";
        elseif isfile(rawFireFile)
            curraw(2) = curraw(2) + 1;
            fireFile = rawFireFile;
            firingType = "raw";
        else
            curraw(3) = curraw(3) + 1;
            fireFile = "null";
            firingType = "null";
        end
        
        if fireFile ~= "null"

            
            firingDat = readmda(fireFile);       % Rows are # Channels, timestamp (starting @ 0), cluster #
            firingDat(:,firingDat(2,:)==0) = []; % Delete any zero time indiceess ... unsure how or why these ever appear
            fireTimes = timeDat(firingDat(2,:));

            % Parse metadata
            metDat = jsondecode(fileread(metFile));
            metDat = metDat.clusters;
            clusters = [metDat.label];
            %Nclust = max(clusters)+any(clusters==0); % RY this causes errors, no more zero cluster eg
            Nclust = numel(clusters);
            [clusters,ic] = sort(clusters,'ascend');
            metDat = metDat(ic);

            % Counters
            taglessCnt = 0;

            % EPOCHS
            for l=progress(1:Nepochs,'Title', 'processing epochs')

                % Allocate
                if firingType == "spikes"
                    spikes{sessionNum}{l}{tetNum} = cell(1,Nclust);
                elseif firingType == "multiunit"
                    multiunit{sessionNum}{l}{tetNum} = cell(1,Nclust);
                end

                % CLUSTERS
                for m=1:Nclust

                    % Determine bounds to sample
                    t1 = epoch_starts(l);
                    if l<Nepochs
                        t2 = epoch_starts(l+1)-1;
                    else
                        t2=timeDat(end);
                    end
                    idx = firingDat(3,:)==clusters(m) & fireTimes>=t1 & fireTimes<=t2;

                    mD = metDat(m).metrics;
                    msID = metDat(m).label;
                    dat = zeros(sum(idx),7);
                    fields = 'time x y dir not_used amplitude(highest variance channel) posindex n_detection_channels';
                    descript = 'spike data from MountainSort 4 (MountainLab-JS)';
                    meanrate = mD.firing_rate;
                    peak_amplitude = mD.peak_amp;
                    dat(:,1) = fireTimes(idx)'/samplerate;
                    dat(:,7) = firingDat(1,idx)';
                    tag = metDat(m).tags; 
                    % refractory_violation_1msec = mD.refractory_violation_1msec; % No longer found in curated mda, possibly due to version update
                    %if any(strcmp(tag,'accepted'))
                    %    tag = tag{strcmp(tag,'accepted')};
                    %end
                    if isempty(tag) && l == 1
                        taglessCnt = taglessCnt + 1;
                    end
                    if any(ismember(string(tag), tagIgnore))
                        continue
                    end
                    if numel(string(tag)) == 1
                        tag = char(string(tag));
                    end
                    if firingType == "curated" && isequal("accepted", string(tag))
                        spikes{sessionNum}{l}{tetNum}{m} = struct('data',dat,...
                            'meanrate',meanrate,...
                            'descript',descript,...
                            'fields',fields,...
                            'timerange',[t1 t2]/samplerate,...
                            'tag',tag,...
                            'metrics', mD,...
                            'msID', msID,...
                            'peak_amplitude',peak_amplitude);
                    end
                    if ~isequal("rejected", string(tag)) && ~ismember("rejected", string(tag))
                        multiunit{sessionNum}{l}{tetNum}{m} = struct('data',dat,...
                            'meanrate',meanrate,...
                            'descript',descript,...
                            'fields',fields,...
                            'timerange',[t1 t2]/samplerate,...
                            'tag',tag,...
                            'metrics', mD,...
                            'msID', msID,...
                            'peak_amplitude',peak_amplitude);
                    end
                end
            end
            if taglessCnt > 0
                warning('tet %d: %d clusters have no tags!', tetNum, taglessCnt);
                if keyboard_on_notag
                    keyboard
                end
            end
        else
            fprintf('No curated or raw firings file found for tetrode %i. Skipping...\n',tetNum);
        end

    end % Iterate tetrode folders

    %% ------------------------------------------------------------
    %% SAVE SHIT
    %% ------------------------------------------------------------
    % SAVE SPIKES
    if processspikes
        save(saveFile,'spikes', '-v7.3');   
    end
   
    % SAVE MULTIUNIT
    if processmultiunit
        spike_inds = ndb.indicesMatrixForm(spikes);
        if ~isempty(spike_inds)
            for sind = spike_inds'
                multiunit = ndb.set(multiunit, sind, ndb.get(spikes, sind));
            end
        end
    end
    save(multiunitSaveFile,'multiunit', '-v7.3');   
else % If spikes already exists and not overwrite
    fprintf('Spikes file @ %s already exists. Skipping...\n',saveFile)
end

% ---------------------------------------------------------------
%% MARKS
% ---------------------------------------------------------------
% In this section, we iterate and create marks files for marked point
% process Notably, I augment my marks with one extra column saying which
% cluster the mark is sampled from. Can yield some extra information in the
% bayesian step.
if processmarks && (overwrite || ~exist(markSaveFile, 'file'))
    for k=progress(1:numel(tetDirs), 'Title', 'Marks: processing tetrode direcetoriees')

        tD = [tetDirs(k).folder filesep tetDirs(k).name];
        tetNum = tet_nums(k);
        metFile = [tD filesep 'metrics_tagged.json'];

        paramsFile = [tD filesep 'params.json'];
        if exist(paramsFile,'file')
            params = jsondecode(fileread(paramsFile));
            if params.samplerate ~= samplerate
                error('Varargin samplerate must match samplingrate in params.json');
            end
        end

        curatedFireFile = [tD filesep 'firings.curated.mda'];
        rawFireFile     = [tD filesep 'firings_raw.mda'];
        marksFile       = [tD filesep 'marks.mda'];
        %timeFile        = [tD filesep 'marks.mda'];
        if isfile(curatedFireFile) 
            fireFile = curatedFireFile;
            firingType = "curated";
        elseif isfile(rawFireFile)
            fireFile = rawFireFile;
            firingType = "raw";
        else
            fireFile = "null";
            firingType = "null";
        end
        
        if fireFile ~= "null" && exist(marksFile,'file')

            firingDat = readmda(fireFile);       % Rows are # Channels, timestamp (starting @ 0), cluster #
            firingDat(:,firingDat(2,:)==0) = []; % Delete any zero time indiceess ... unsure how or why these ever appear
            fireTimes = timeDat(firingDat(2,:));
            markDat   = squeeze(readmda(marksFile)); % timestamp * numTimesInMark * tetrodeChannel, where numTimesInMark=1

            % Parse metadata
            metDat = jsondecode(fileread(metFile));
            metDat = metDat.clusters;
            clusters = [metDat.label];
            %Nclust = max(clusters)+any(clusters==0); % RY this causes errors, no more zero cluster eg
            Nclust = numel(clusters);
            [clusters,ic] = sort(clusters,'ascend');
            metDat = metDat(ic);

            % Counters
            taglessCnt = 0;

            % EPOCHS
            for l=progress(1:Nepochs,'Title', 'processing epochs')

                % Allocate
                marks{sessionNum}{l}{tetNum} = cell(1,Nclust);

                % CLUSTERS
                for m=1:Nclust

                    % Determine bounds to sample
                    t1 = epoch_starts(l);
                    if l<Nepochs
                        t2 = epoch_starts(l+1)-1;
                    else
                        t2=timeDat(end);
                    end
                    idx = firingDat(3,:)==clusters(m) & fireTimes>=t1 & fireTimes<=t2;

                    % Setup metrics
                    mD = metDat(m).metrics;
                    msID = metDat(m).label; 

                    % Construct data
                    descript = 'spike data from MountainSort 4 (MountainLab-JS)';

                    % Capture mark data
                    times = fireTimes(idx)'/samplerate;
                    dat = markDat(:, idx)';
                    if keepMarkClusterInformation
                        dat = [dat, repmat(m, size(dat,1), 1)];
                    end
                    
                    % Tag-related computations
                    tag = metDat(m).tags; 
                    if isempty(tag) && l == 1
                        taglessCnt = taglessCnt + 1;
                    end
                    if ismember(string(tag), tagIgnore)
                        continue
                    end
                    if numel(string(tag)) == 1
                        tag = char(string(tag));
                    end
                    if ~isequal("rejected", string(tag)) && ~ismember("rejected", string(tag))
                        marks{sessionNum}{l}{tetNum}{m} = struct('data',single(dat),...
                            'times', times,...
                            'timerange',[t1 t2]/samplerate,...
                            'tag',{tag},...
                            'msID', msID,...
                            'metrics', mD);
                    end
                end
            end
            if taglessCnt > 0
                warning('tet %d: %d clusters have no tags!', tetNum, taglessCnt);
            end

        else
            fprintf('No curated or raw firings file found for tetrode %i. Skipping...\n',tetNum);
        end
    end % Iterate tetrode folders

    % Now lets collapse these marks per cluster into just marks on a tetrode
    if ~keepMarkClusterSeparate
        indices = ndb.indicesMatrixForm(marks);
        indices = unique(indices(:,1:3), 'rows');
        for ind = indices'
            overall_struct = struct();
            mark_set = ndb.get(marks, ind);
            empty = cellfun(@isempty, mark_set);
            number = cellfun(@numel, mark_set);
            if any(number>1)
                error("FUck")
            end
            mark_set = ndb.toNd(mark_set(~empty));
            overall_struct.times     = cat(1,mark_set.times);
            overall_struct.data      = cat(1,mark_set.data);
            [~,idx] = sort(overall_struct.times);
            overall_struct.times = overall_struct.times(idx);
            overall_struct.data  = overall_struct.data(idx, :);
            overall_struct.timerange = mark_set(1).timerange;
            marks{ind(1)}{ind(2)}{ind(3)} = overall_struct;
        end
    end

    % ----------------------------------------------------------------------
    %% SAVE
    % ----------------------------------------------------------------------
    DAYWISE = 1;
    ndb.save(marks, animID, 'marks', 'dim', DAYWISE);
end


