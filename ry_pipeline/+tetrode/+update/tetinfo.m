function tetinfo(animID, day)
% createtetinfostruct(datadir,animID,append)
%
% This function creates a tetinfo file in the animal's data directory.
% For each tetrode, the depth and number of cells is saved.  If a tetinfo file
% exists and new data is being added, set APPEND to 1.

if ndbFile.exist(animID,'tetinfo')
    tetinfo = ndb.load(animID, 'tetinfo');
else
    tetinfo = {};
end
eeg = ndb.load(animID, 'eeg', 'indices', day);
eegInds = ndb.indicesMatrixForm(eeg);

if ndbFile.exist(animID,'spikes')
    spikes = ndb.load(animID, 'spikes', 'indices', day);
else
    spikes = {};
end

for ind = eegInds'
    
    edat = ndb.get(eeg,ind);

    if isfield(edat,'depth')
        tdat.depth = edat.depth;
        tdat.numcells = 0;
    end
    if ndb.exists(spikes,ind)
        sdat = ndb.get(spikes,ind);
        numcells = length(ndb.indicesMatrixForm(sdat));
        tdat.numcells = numcells;
    end
    tetinfo = ndb.set(tetinfo, ind, tdat);
   
 end
   
ndb.save(tetinfo,animID,'tetinfo', 0);
