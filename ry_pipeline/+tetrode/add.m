function add(animID, dayepoch, label, varargin)
% Generalizes addition of data to tetinfo
%
% if dayepoch empty, carries out for all dayepochs
% dayepoch can be a day or a dayepoch


tetrodes = varargin(1:2:end);
values   = varargin(2:2:end);

if numel(tetrodes) ~= numel(values)
    error("number of tetrode lists must equal the number of values");
end
if numel(tetrodes) == 0
    error("please provide list of tetrode and list of attributes for those lists");
end

if ndbFile.exist(animID, 'tetinfo')
    tetinfo = ndb.load(animID, 'tetinfo');
else
    tetinfo = {};
end

% -----------------------------------------------------------------------------
% INFO files :: Get cell and multiunit info files
% -----------------------------------------------------------------------------
if ndbFile.exist(animID,'cellinfo')
    cellinfo = ndb.load(animID, 'cellinfo');
else
    warning(sprintf('cellinfo for %s not found', animID))
    cellinfo = {};
end
if ndbFile.exist(animID,'multiinfo')
    multiinfo = ndb.load(animID, 'multiinfo');
else
    warning(sprintf('multiinfo for %s not found', animID))
    multiinfo = {};
end
% -----------------------------------------------------------------------------

% Determine what we'll be processing
inds_cellinfo  = ndb.indicesMatrixForm(cellinfo);
inds_multiinfo = ndb.indicesMatrixForm(multiinfo);

% -----------------------------------------------------------------------------
% TABLE files
% -----------------------------------------------------------------------------
if ndbFile.exist(animID,'tetinfoTable')
    tetinfoTable = ndb.load(animID, 'tetinfoTable');
    if ~ismember(label, string(fieldnames(tetinfoTable)))
        tetinfoTable.(label) = repmat(NaN, height(tetinfoTable), 1);
    end
    tetinfoTable = ndb.load(animID, 'tetinfoTable');
else
    tetinfoTable = {};
end
if ndbFile.exist(animID,'cellinfoTable')
    cellinfoTable = ndb.load(animID, 'cellinfoTable');
    if ~ismember(label, string(fieldnames(cellinfoTable)))
        cellinfoTable.(label) = repmat(NaN, height(cellinfoTable), 1);
    end
else
    cellinfoTable = {};
end
if ndbFile.exist(animID,'multiinfoTable')
    multiinfoTable = ndb.load(animID, 'multiinfoTable');
    if ~ismember(label, string(fieldnames(multiinfoTable)))
        multiinfoTable.(label) = repmat(NaN, height(multiinfoTable), 1);
    end
    multiinfoTable = ndb.load(animID, 'multiinfoTable');
else
    multiinfoTable = {};
end
% -----------------------------------------------------------------------------

% Create convenience lambda function
eegInds = ndbFile.indicesMatrixForm(animID,'eeg', 'indices', dayepoch);    

% -----------------------------------------------------------------------------
% Add user information to these structures (info struct and info tables)
% -----------------------------------------------------------------------------
for index = progress(eegInds', 'Title', char("Adding " + label))

    fprintf('\n %d %d %d', index);

    if ndb.exist(tetinfo,index)
        tdat = ndb.get(tetinfo,index);
    else
        tdat = struct();
    end

    tetrode = index(end);
    s = matchTheSet(tetrodes, tetrode);

    % If we have a match, assign!
    % ---------------------------
    if s ~= -1

        % Label tetinfo
        % -------------
        tdat.(label) = values{s};
        tetinfo = ndb.set(tetinfo, index, tdat);

        % Add to multiinfo
        % ----------------
        if ~isempty(inds_multiinfo)
            % Add to multiinfo
            for mind = progress(getMatchingEegInds(inds_multiinfo, index'),...
                    'Title', 'Multiunit')
                mdat = ndb.get(multiinfo, mind);
                mdat.(label) = values{s};
                multiinfo = ndb.set(multiinfo, mind, mdat);
            end
            % Add to multiinfoTable
            if ~isempty(multiinfoTable)
                rows = all(multiinfoTable(:, ...
                           ["day","epoch","tetrode"]) == index,2);
                multiinfoTable(rows, label) = value{s};

            end
        else
            warning("not adding multiinfo: missing multiinfo")
        end

        % Add to cellinfo
        if ~isempty(inds_cellinfo)
            for cind = progress(getMatchingEegInds(inds_cellinfo, index'),...
                    'Title', 'Cells')
                cdat = ndb.get(cellinfo, cind);
                cdat.(label) = values{s};
                cellinfo = ndb.set(cellinfo, cind, cdat);
            end
        else
            warning("not adding cellinfo: missing cellinfo")
        end
    end


end

% Save the appended data structures
% ---------------------------------
ndb.save(tetinfo,   animID, 'tetinfo',   0);
ndb.save(cellinfo,  animID, 'cellinfo',  0);
ndb.save(multiinfo, animID, 'multiinfo', 0);

function s = matchTheSet(tetrodes, tetrode)

    s = -1;
    for t  = 1:numel(tetrodes)
        if ismember(tetrode, tetrodes{t})
            s = t;
        end
    end

function out = getMatchingEegInds(x, eegInds) 
    if isempty(x)
        out = false;
    else
        out = x(ismember(x(:,1:3), eegInds, 'rows'),:)';
    end
