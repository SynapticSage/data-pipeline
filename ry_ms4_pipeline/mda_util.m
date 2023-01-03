function [out, tetrodePerDir] = mda_util(dayDirs,varargin)
    % out = mda_util(dayDirs,varargin)
    % dayDirs should be a list of raw day directories, each containing a .mda folder
    % use exportmda or RN_TrodesExtractionBuilder to generate mda files from rec files.
    % creates mountainsort directories in the dataDir (results dir) and returns
    % a list of tetrode results directories
    % Required: recording files have names AnimID_Day_Date_Epoch (e.g.
    % RZ2_02_180228_1Sleep or RW2_01_20180913_2Linear)
    % Required Directory Structure:
    %   -ExpFolder
    %   |-> animID (raw directory)
    %       |-> 01_181011 (day directory)
    %           |-> animID_01_181011.mda (mda directory) or animID_01_180811_1Sleep.mda (if only 1 epoch this will happen, its ok)
    %           .
    %           .
    %       .
    %       .
    %    |-> animID_direct  (results directory)
    % NAME-VALUE Pairs:
    %   params  : structure with params for clustering (default = struct('samplerate',30000)) 
    %   tet_list: list of tetrodes to process (default is all in folder)
    %   topDir  : top animal dir containing animID (with raw data day directories) and animID_direct
    %   dataDir : data directory for processed data output (animID_direct)
    %   topDir and dataDir are determined from expected file structure and parsed from mda directory, overriding these is if your data is not kept in this file structure
    % 
    % Ryan : changed to allow user to specify the regular expression to parse their data
    % Ryan : changed to ouput data about the directory - the tetrode corresponding to each
    %        ... this was needed to allow user to choose different filtration for pfc and ca1
    %        tetrodes. [300 6000] for pfc and [600 6000] for ca1 (I havd some very low resolution
    %        cells in my data).
    
    pat = '(?<anim>[A-Z]+[0-9]+)_(?<day>[0-9]{2})_(?<date>[0-9]+)_*(?<epoch>[0-9]*)(?<epoch_name>\w*).mda';
    params = struct('samplerate',30000);
    topDir   = '';
    dataDir  = '';
    tet_list = [];
    assignVars(varargin)
    
    if isempty(tet_list)
        tet_list = 1:100;
    end
    if ~isempty(topDir)
        topDirOverride = 1;
    else
        topDirOverride = 0;
    end
    if ~isempty(dataDir)
        dataDirOverride = 1;
    else
        dataDirOverride = 0;
    end

    if ~any(strcmpi(fieldnames(params),'samplerate'))
        params.samplerate = 30000;
    end

    if ~iscell(dayDirs)
        dayDirs = {dayDirs};
    end
    out = {};
    tetrodePerDir = [];
    for k=1:numel(dayDirs)
        dd = dayDirs{k};
        fprintf('Running mda_util.m on %s...\n',dd);
        if dd(end)==filesep
            dd = dd(1:end-1);
        end
        [~,a] = fileparts(dd);
        if ~isdir(dd) || (isempty(a) || all(a=='.'))
            continue;
        end
        
        if dd(end)==filesep
            dd = dd(1:end-1);
        end
        if ~topDirOverride
            topDir = fileparts(fileparts(dd));
        end
        mdaDir = dir([dd filesep '*.mda']);
        if isempty(mdaDir)
            error('No MDA directory found in %s. Please run exportmda and try again.',dd)
        end
        parsed = regexp(mdaDir.name,pat,'names');
        if ~dataDirOverride
            dataDir = [topDir filesep parsed.anim '_direct' filesep];
        end
        particles = string({parsed.anim, parsed.day, parsed.date});
        if isempty(particles)
            warning("Is your regex pattern correct?")
            keyboard
        end
        particles = string(particles);
        particles = particles(strlength(particles)~=0);
        particles = char(join(particles,"_"));
        resDir = [dataDir filesep 'MountainSort' filesep particles '.mountain' filesep];
        mkTree(resDir);

        mdaFiles = dir([mdaDir.folder filesep mdaDir.name filesep '*.mda']);
        pat2 = '\w*.nt(?<tet>[0-9]+).mda';
        for l=1:numel(mdaFiles)
            % if its the timestamps file, copy it to the resDir 
            if ~isempty(strfind(mdaFiles(l).name,'timestamps'))
                create_prv([mdaFiles(l).folder filesep mdaFiles(l).name],[resDir mdaFiles(l).name '.prv']);
                continue;
            end
            parsedF = regexp(mdaFiles(l).name,pat2,'names');
            if isempty(parsedF) || isempty(parsedF.tet) || ~any(tet_list==str2double(parsedF.tet))
                continue;
            end
            tetResDir = [resDir char(join(particles,"_")) '.nt' parsedF.tet '.mountain' filesep];
            mkTree(tetResDir);
            % make params file
            fid = fopen([tetResDir 'params.json'],'w+');
            fwrite(fid,jsonencode(params));
            fclose(fid);

            % create prv file
            srcFile = [mdaFiles(l).folder filesep mdaFiles(l).name];
            destFile = [tetResDir 'raw.mda.prv'];
            create_prv(srcFile,destFile);

            % Store tetResDir for output
            out = [out tetResDir];
            tetrodePerDir = [tetrodePerDir, str2double(parsedF.tet)];
        end
    end
