function eegref2eeg(animal, day)

        inds = ndbFile.indicesMatrixForm(animal, "eegref");
        inds = inds(inds(:,1)==day, :);

        % Find reference per area and area
        ndb.load(animal, "tetinfo", 'inds', day, 'get', true)
        [area, hemisphere, descrip, indices] = ndb.cellfetch(tetinfo, ["area", "hemisphere","descrip"]);

        Info = animalinfo(animal);
        areanumbers = [1, 2, 3];
        [tetStruct, areas, tetList, refList] = ry_getAreasTetsRefs(...
            'configFile', Info.configFile,...
            'removeAreas', [ "SuperDead" ],...
            'selectMostFrequentRef', true);
        refList(hpcL) = refList(hpcR);


        tab = table(indices(:,1), indices(:,2), ...
            string(area)', string(hemisphere)',...
            string(descrip)',...
            'VariableNames', {'epoch', 'tetrode','area','hemisphere','descrip'});

        areanumber = nan(size(tab,1),1);
        inds = (tab.area == "CA1" & tab.hemisphere == "left");
        areanumber(inds) = ones(sum(inds),1);
        inds = (tab.area == "CA1" & tab.hemisphere == "right");
        areanumber(inds) = 2*ones(sum(inds),1);
        inds = (tab.area == "PFC");
        areanumber(inds) = 3*ones(sum(inds),1);

        inds = (tab.descrip == "CA1Ref");
        areanumber(inds) = ones(sum(inds),1);
        inds = (tab.descrip == "PFCRef");
        areanumber(inds) = 3*ones(sum(inds),1);

        tab.areanumber = areanumber;
        tab = tab(~isnan(tab.areanumber),:);
        tab.ref = [refList{tab.areanumber}]';

        for r = progress(1:height(tab))
            row = tab(r, :);
            [epoch, tetrode, ref] = deal(row.epoch, row.tetrode, row.ref);
            e = ndb.load(animal, 'eegref', 'inds', [day, epoch, tetrode]);
            if ~ndb.exist(e, [day, epoch, tetrode])
                continue
            end
            e = ndb.get(e, [day, epoch, tetrode]);
            r = ndb.load(animal, 'eegref', 'inds', [day, epoch, ref]);
            r = ndb.get(r, [day, epoch, ref]);

            if e.referenced == 0
                keyboard
            end

            E = e.data + r.data;
            e.data = E;
            e.referenced = 0;
            E = {};
            E = ndb.set(E, [day, epoch, tetrode], e);

            ndb.save(E, animal, 'eeg', 3)
        end
end
