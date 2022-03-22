function assignarea(animID, dayepoch, varargin)
% Assigns area related information to raw structure
ip = inputParser;
ip.addParameter('folderGlob', '*.mda');
ip.addParameter('epochfilt', '');
ip.addParameter('dataname', 'deepinsight');
ip.addParameter('resample', []);
ip.addParameter('downsample', []);
ip.addParameter('transpose', false);
ip.KeepUnmatched= true;
ip.parse(varargin{:})
Opt = ip.Results;


tetinfo = ndb.load(animID,'tetinfo','indices',dayepoch);
tiInds  = ndb.indicesMatrixForm(tetinfo);
rawInds = ndbFile.indicesMatrixForm(animID, 'deepinsight',...
    'indices', dayepoch);
indices =  intersect(rawInds, tiInds(:,1:2), 'rows');
if ~isempty(Opt.epochfilt) && (isstring(Opt.epochfilt) || ischar(Opt.epochfilt))
    task = ndb.load(animID, 'task');
    eInds = evaluatefilter(task, Opt.epochfilt);
    indices = intersect(indices, eInds, 'rows');
elseif ~isempty(Opt.epochfilt) && isnumeric(Opt.epochfilt)
    if isrow(Opt.epochfilt) || iscolumn(Opt.epochfilt)
        indices = indices(ismember(indices(:, end), Opt.epochfilt(:)), :);
    end
end

for ind = indices'

    day    =  ind(1);
    epoch  =  ind(2);

    resultFile = sprintf('%s/RAW/%s%s%02d-%02d.mat', ...
                         ndbFile.animdir(animID), animID, Opt.dataname, day, epoch);
    M = matfile(resultFile, 'Writable', true);

    % Compute integers for area 1 - hpc area 2 - pfc
    areares = ndb.get(tetinfo, [day, epoch]);
    areares = cellfetch(areares,'area');
    filt = areares.index;
    ind = cellfun(@(item) ~isstring(item)  &&  ~ischar(item), areares.values);
    areares.values(ind) = {""};
    area  = string([]);
    area(filt)  = string(areares.values);
    compfilt = 1:max(filt);
    compfilt = compfilt(~ismember(compfilt,filt));
    area(compfilt) = "";
    [uArea,~,area]  = unique(area);
    areaString = uArea(area);
    num = find(uArea == "");
    area(area==num)  = nan;
    if max(area) == numel(uArea)
        area =  area - 1;
    end
    if Opt.transpose == false
        M.area       = area(M.tetrodes)';
        M.areaString = areaString(M.tetrodes)';
    else
        M.area       = area(M.tetrodes);
        M.areaString = areaString(M.tetrodes);
    end
    clear M;
end
