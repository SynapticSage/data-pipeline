function out = convert_ml_to_FF(animID,resDir,sessionNum,varargin)
    % Convert mountainsort curated spikes to filter framework spikes files
    % animID : animal ID
    % resDir : mountainlab results directory for a single day
    % sessionNum: number of day
    % NAME-VALUE Pairs:
    % samplerate : sampling rate in Hz, default 30000
    % min_epoch_break : minumum recording time break to classify an epoch, 1 sec default
    % overwrite : 1 or 0 (default), whether to overwrite an existing spikes file

    samplerate = 30000;
    min_epoch_break=1;
    overwrite = 0;

    assignVars(varargin)

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
    saveFile = sprintf('%s%s%sspikes%02i.mat',resDir,filesep,animID,sessionNum);
    if exist(saveFile,'file') && ~overwrite
        fprintf('Spikes file @ %s already exists. Skipping...\n',saveFile)
        return;
    end

    % Determine epoch start times by looking for gaps longer than 1 sec
    gaps = diff(timeDat);
    epoch_gaps = find(gaps>=min_epoch_break*samplerate);
    epoch_starts = timeDat([1 epoch_gaps]);
    Nepochs = numel(epoch_starts);
    fprintf('Detected %i epochs. Start times:\n',Nepochs);
    disp(epoch_starts');

    % get tet numbers
    pat = '\w*.nt(?<tet>[0-9]+).\w*';
    parsed = cellfun(@(x) regexp(x,pat,'names'),{tetDirs.name});
    tet_nums = str2double({parsed.tet});
    Ntets = max(tet_nums);
    fprintf('Detected %i tetrodes. Tetrodes:\n',Ntets);
    disp(tet_nums');
    drawnow;

    spikes = cell(1,sessionNum);
    spikes{sessionNum} = cell(1,Nepochs);
    spikes{sessionNum}(:) = {cell(1,Ntets)};

    for k=1:numel(tetDirs)
        tD = [tetDirs(k).folder filesep tetDirs(k).name];
        tetNum = tet_nums(k);
        metFile = [tD filesep 'metrics_tagged.json'];
        fireFile = [tD filesep 'firing.curated..mda'];
        if ~isfile(fireFile)
            fprintf('No curated firings file found for tetrode %i. Skipping...\n',tetNum);
            continue;
        end

        metDat = jsondecode(fileread(metFile));
        metDat = metDat.clusters;
        fireDat = readmda(fireFile); % Rows are # Channels, timestamp (starting @ 0), cluster #

        clusters = [metDat.label];
        Nclust = max(clusters)+any(clusters==0);
        [clusters,ic] = sort(clusters,'ascend');
        metDat = metDat(ic);

        % TODO: check params.json for smaplerate and error if not matching

        fireTimes = timeDat(fireDat(2,:));
        for l=1:Nepochs
            spikes{sessionNum}{l}{tetNum} = cell(1,Nclust);
            for m=1:Nclust
                t1 = epoch_starts(l);
                if l<Nepochs
                    t2 = epoch_starts(l+1)-1;
                else
                    t2=timeDat(end);
                end
                idx = fireDat(3,:)==clusters(m) & fireTimes>=t1 & fireTimes<=t2;
                mD = metDat(m).metrics;
                dat = zeros(sum(idx),7);
                fields = 'time x y dir not_used amplitude(highest variance channel) posindex n_detection_channels';
                descript = 'spike data from MountainSort 4 (MountainLab-JS)';
                meanrate = mD.firing_rate;
                peak_amplitude = mD.peak_amp;
                % refractory_violation_1msec = mD.refractory_violation_1msec; % No longer found in curated mda, possibly due to version update
                dat(:,1) = fireTimes(idx)'/samplerate;
                dat(:,7) = fireDat(1,idx)';
                tag = metDat(m).tags; 
                if any(strcmp(tag,'accepted'))
                    tag = tag{strcmp(tag,'accepted')};
                end
                spikes{sessionNum}{l}{tetNum}{m} = struct('data',dat,'meanrate',meanrate,...
                    'descript',descript,'fields',fields,...
                    'timerange',[t1 t2]/samplerate,...
                    'tag',tag,...
                    'peak_amplitude',peak_amplitude);
            end
        end
    end

    save(saveFile,'spikes');   
    out = saveFile;
