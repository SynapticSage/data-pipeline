function varargout = ry_createNQRawPosFiles(dayDir, dataDir, animID, session, varargin)
% ry_deeplabcut.generateRawPosFiles

ip = inputParser;
ip.addParameter('tableOutputDir',[],@(x) ischar(x) || isstring(x));
ip.addParameter('cmperpixel',[], @isnumeric);
ip.addParameter('sessionRecs',{}, @iscell);
ip.addParameter('filtered', true, @(x) islogical(x) || isnumeric(x)); % Use the filtered version of deeplabcut result?
ip.addParameter('dlcDirectory', [], @(x) ischar(x) || isstring(x));
ip.parse(varargin{:})
opt = ip.Results;

if isempty(opt.dlcDirectory)
    opt.dlcDirectory = dayDir;
end
opt.dlcDirectory = string(opt.dlcDirectory);

currdir = pwd;
onCleanup( @() cd(currdir) ); % Whenever the function exits, go back to current folder (even if it errors out and never reachees functionst that come bring us back)

%% Obtain epoch boundaries with default 1 sec gap
cd(dayDir);
[epochTimes, fileOffsets] = getEpochs(1);  %assumes that there is at least a 1-second gap in data between epochs if no .trodesComments file is found
cd(currdir);


%% Which filenames should we expect in the dlcDirectory
if isempty(opt.sessionRecs)
    opt.sessionRecs = dir(fullfile(dayDir,'*.videoTimeStamps'));
    files = string({opt.sessionRecs.name});
    % TODO order by trdoesComment contents just in case
else
    files = string(opt.sessionRecs);
end

assert(numel(files) == size(epochTimes,1), 'fewer session recs than trodes comments');

%% Iterate each and create raw pos from dlc *.csv files
for file = progress(files,'Title','Procsesing raw pos')
    
    % Refresh rawpos struct
    rawpos={};
    rawpos{session}={};

    %file = replace(file, '.rec', '.csv');
    [path, name, ext] = fileparts(file);
    epoch = find(ismember(cellfun(@(x) replace(x,'.trodesComments',''),...
        {fileOffsets.file}, 'UniformOutput',false), name));

    % Read deeplabcut estimates per frame of video
    if opt.filtered
        csvfiles = dir( string(opt.dlcDirectory) + filesep + name + "*dlc.filtered.csv" );
    else
        csvfiles = dir( string(opt.dlcDirectory) + filesep + name + "*dlc.csv" );
    end
    if isempty(csvfiles)
        warning('DLC csv for %s not found', name);
        continue
    end
    csvfile = string(csvfiles(1).folder) + filesep+ csvfiles(1).name;
    tableOpt = detectImportOptions(csvfile, 'Range', 3); 
    deeplabcutTable = readtable(csvfile, tableOpt);
    tableOpt.DataLines = [1 3];
    tableOpt.VariableTypes(:) = {'string'};
    dlcMetadata = table2array(readtable(csvfile,tableOpt));

    SCORE = 1;
    POINT = 2;
    TYPE  = 3;

    % Reorder points such that left right points are listed first followed
    % by any other points the deeplabcut was trained to recognize
    left_points = contains(dlcMetadata(POINT,:), 'left');
    right_points = contains(dlcMetadata(POINT,:), 'right');
    neither_points = ~(left_points | right_points);
    new_left = 1:sum(left_points);
    new_right = new_left(end)+1:new_left(end)+sum(right_points);
    new_neither = new_right(end)+1:new_right(end)+sum(neither_points);

    tmpDlcMetadata = dlcMetadata;
    tmpDeeplabcutTable = deeplabcutTable;
    dlcMetadata(:,new_left)    = tmpDlcMetadata(:,left_points);
    dlcMetadata(:,new_right)   = tmpDlcMetadata(:,right_points);
    dlcMetadata(:,new_neither) = tmpDlcMetadata(:,neither_points);
    deeplabcutTable(:,new_left)    = tmpDeeplabcutTable(:,left_points);
    deeplabcutTable(:,new_right)   = tmpDeeplabcutTable(:,right_points);
    deeplabcutTable(:,new_neither) = tmpDeeplabcutTable(:,neither_points);

    % Get time stamps per time frame
    timestampFile = replace(file, '.rec', '.videoTimeStamps');
    timestampFile = fullfile(dayDir, timestampFile);
    [timestamps, clockrate] = readCameraModuleTimeStamps(timestampFile);

    % Apply offset
    i = string({fileOffsets.file}) == replace(file, '.videoTimeStamps',  '.trodesComments');
    offset = fileOffsets(i).offset;
    timestamps = timestamps + offset;

    % Find xyInds and probInds
    xyInds = dlcMetadata(3,:) == "x" | dlcMetadata(3,:) == "y";
    probInds = dlcMetadata(3,:) == "likelihood";
    nPoints = numel(unique(dlcMetadata(POINT,:)))-1;

    % Setup our tmp structure
    tmp = struct('clockrate', clockrate);
    tmp.(dlcMetadata(1,1)) = dlcMetadata(1,2); % Annotate which scorer was used to produce this data
    fields = dlcMetadata(2,xyInds) + "_" + dlcMetadata(3,xyInds); 
    tmp.fields = "timestamp " + join(fields," ");
    % Table for the actual xy data
    tmp.dataheader = ["timestamp" dlcMetadata(POINT,xyInds);...
                         "t"         dlcMetadata(TYPE,xyInds)];
    tmp.data(:,1) = timestamps;
    tmp.data(:, 2:2 + nPoints *2-1) = ...
        table2array(deeplabcutTable(:, xyInds));
    % Table for the likelihood data
    tmp.likelihoodheader = ["timestamp" dlcMetadata(POINT, probInds);...
                               "t"         dlcMetadata(TYPE,  probInds)];
    tmp.likelihood(:,1) = timestamps;
    tmp.likelihood(:, 2:2 + nPoints -1) = ...
        table2array(deeplabcutTable(:, probInds));
    tmp.units = 'pixel';
    tmp.filtered = opt.filtered; % Whether deeplabcut ARMA statespace filtered
    startStr = datestr(seconds(epochTimes(epoch,1)), 'HH:MM:SS');
    endStr   = datestr(seconds(epochTimes(epoch,2)), 'HH:MM:SS');
    tmp.descript= {['position data from ' startStr ' to ' endStr]};

    % Cm per pixel conversion?
    if ~isempty(opt.cmperpixel)
        tmp.cmperpixel = opt.cmperpixel;
        tmp.units = 'cm';
        tmp.data(:,2:end) = tmp.data(:,2:end) * opt.cmperpixel;
    else
        tmp.cmperpixel = [];
    end
    
    % Save rawpos
    rawpos{session}{epoch} = tmp;
    save(fullfile(dataDir, sprintf('%srawpos%02d-%02d', animID, session, epoch)), 'rawpos')

    % Table?
    %if ~isempty(opt.tableOutputDir)
    %    T  = ry_deeplabcut.generateTable;
    %    if ~exist(opt.tableOutputDir,'dir')
    %        mkdir(opt.tableOutputDir)
    %    end
    %    writetable(T, fullfile(opt.tableOutputDir,sprintf('%srawpos%02d-%02d.csv', animID, session, epoch)));
    %end

end


%%%%%%%%%%%%%%%%%%%%%%%%%
% next, create one rawpos for day
%%%%%%%%%%%%%%%%%%%%%%%%%
rawpos = ndBranch.load(animID, 'rawpos','simplefilter',session+"-"); % Load up all rawpos;
% Ensure that rawpos actually reaches the final epoch
if size(epochTimes,1) > numel(rawpos{session})
    rawpos{session}{size(epochTimes,1)} = {};
end
ndBranch.save(rawpos, animID, 'rawpos', 1); % Save it  by day

if nargout > 0
    varargout{1} = rawpos;
end
