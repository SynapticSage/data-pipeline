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

% Get cell and multiunit info files
if ndbFile.exist(animID,'cellinfo')
    cellinfo = ndb.load(animID, 'cellinfo');
else
    cellinfo = {};
end
inds_cellinfo  = ndb.indicesMatrixForm(cellinfo);
if ndbFile.exist(animID,'multiinfo')
    multiinfo = ndb.load(animID, 'multiinfo');
else
    multiinfo = {};
end
inds_multiinfo = ndb.indicesMatrixForm(multiinfo);

% Create convenience lambda function
eegInds = ndbFile.indicesMatrixForm(animID,'eeg',...
    'indices', dayepoch);    
getMatchingEegInds = @(x, eegInds) x(ismember(x(:,1:3), eegInds, 'rows'),:)';

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
        for mind = progress(getMatchingEegInds(inds_multiinfo, index'), 'Title', 'Multiunit')
            mdat = ndb.get(multiinfo, mind);
            mdat.(label) = values{s};
            multiinfo = ndb.set(multiinfo, mind, mdat);
        end

        % Add to cellinfo
        for cind = progress(getMatchingEegInds(inds_cellinfo, index'), 'Title', 'Cells')
            cdat = ndb.get(cellinfo, cind);
            cdat.(label) = values{s};
            cellinfo = ndb.set(cellinfo, cind, cdat);
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
