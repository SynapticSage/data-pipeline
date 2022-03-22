function withTetinfo(animal, day)
%updates cellinfo to include fields from tetinfo, e.g. brain area, hemishphere, etc


tetinfo  = ndb.load(animal, 'tetinfo',  'ind', day);
cellinfo = ndb.load(animal, 'cellinfo', 'ind', day);

% Iterate entries of cellinfo
for ind = progress(ndb.indicesMatrixForm(cellinfo)', 'Title', 'Adding tetinfo to cellinfo')


    if all(ndb.exist(tetinfo, ind(1:3))) && all(ndb.exist(cellinfo, ind))
        T = ndb.get(tetinfo,  ind(1:3));
        C = ndb.get(cellinfo, ind);
    end

    for field = string(fieldnames(T))'
        C.(field) = T.(field);
    end
    
    cellinfo = ndb.set(cellinfo, ind, C);

end

% Save cellinfo
ALL_IN_ONE = 0;
ndb.save(cellinfo, animal, 'cellinfo', 'dim', ALL_IN_ONE);
