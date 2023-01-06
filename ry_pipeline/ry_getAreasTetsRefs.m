function [tetinfo, areas, tetList, refList] = ry_getAreasTetsRefs(varargin)

ip = inputParser;

ip.addParameter('configDir',[]);
ip.addParameter('configFile',[]);

ip.addParameter('selectMostFrequentRef',false); % if multiple references, use frequency to find the ref used for the brain area?

ip.addParameter('removeAreas',[],@(x) isstring(x) || ischar(x));
ip.addParameter('removalKeyValue', []);

ip.addParameter('keyDict', containers.Map({'area'}, {'Area'}));
ip.parse(varargin{:})
Opt = ip.Results;

% Preprocess optional inputs
% --------------------------
for key = Opt.keyDict.keys()
    val = Opt.keyDict(key{1});
    if ~endsWith(val, '/')
        val = string(val) + '/';
    end
    if ~startsWith(val, ';')
        val =  ";" + val;
    end
    Opt.keyDict(key{1}) = char(val);
end
% --------------------------


if ~isempty(Opt.configDir)
    currdir = pwd;
    cd( Opt.configDir );
    files = dir('*.trodes*onf');
    configFile = files(1);
    cd(currdir);
    configFile = fullfile(configFile.folder, configFile.name);
elseif ~isempty(Opt.configFile)
    configFile = Opt.configFile;
else
    error('Pleease provide configFile or configDir')
end

% XML2struct requires an absolute realpath in the the truest sense
[path,name,ext]=fileparts(configFile);
currdir=pwd;
cd(path);newpath=pwd;cd(currdir);
configFile=replace(configFile,path,newpath);
xml = xml2struct(configFile);

% Obtain the spikeNTrode attributes
spikeNtrode = ndb.toNd(xml.Configuration.SpikeConfiguration.SpikeNTrode);
attributes  = {spikeNtrode.Attributes};
attributes  = cat(2,attributes{:});

% This method relies on having tags to mark variables thusly: Area/AreaName and to find out if it's a ref channel, we check if id == refChan


tetCnt = 0;
tetinfo = struct();
for tet = attributes
    tetCnt = tetCnt + 1;

    tetinfo(tetCnt).id  = str2double(tet.id);

    % Add tags from the grouping keys
    for key = Opt.keyDict.keys()
        key = key{1};
        searchTerm = Opt.keyDict(key);
        loc = strfind(tet.groupingTags, searchTerm);
        %assert(numel(loc)==1)
        %tagDelim = ';';
        %tags = strfind(tet.groupingTags, tagDelim);
        %tags = tags(tags>loc);
        tetinfo(tetCnt).isRef = 0; % default value : references computed later in function
        if ~isempty(loc)
            keyCap = key; keyCap(1) = upper(key(1));
            delim = char(";" + string(keyCap) + "/");
            areaTextRange = strsplit(tet.groupingTags, delim);
            [~,idx] = max(cellfun(@length, areaTextRange));
            txt = areaTextRange{idx};
            %if numel(tags)>0
            %    areaTextRange = loc+numel(searchTerm):min(tags,numel(tet.groupingTags));
            %else
            %    areaTextRange = loc+numel(searchTerm):numel(tet.groupingTags);
            %end
            tetinfo(tetCnt).(key)  = string(txt);
            tetinfo(tetCnt).(key)  = tetinfo(tetCnt).(key).erase(';');
        else
            tetinfo(tetCnt).(key)  = string(nan);
            %error("key " + string(key) + " not found!")
        end
    end
    
end

% Reference discovery
references = str2double(cellfun(@string, {attributes.refNTrodeID}));
uReferences = unique(references);
for ref = uReferences
    reffilter = [tetinfo.id] == ref;
    tetinfo(reffilter).isRef = 1;
end


% Build vectors/matrices that our preprocessing expects
areas = unique([tetinfo.area]);
if ~isempty(Opt.removeAreas)
    Opt.removeAreas = string(Opt.removeAreas);
    areas = areas(~ismember(areas,Opt.removeAreas));
end

% Build tetlist and reflist and finalize list of areas
tetList = {};
refList = {};
area_cnt = 0;
areas = [tetinfo.area];
uAreas = unique(areas);

for area = uAreas

    area_cnt = area_cnt + 1;

    area_filter   = areas == area;
    nonref_filter = [tetinfo.isRef] == 0;
    ref_filter    = [tetinfo.isRef] == 1;

    if sum(ref_filter & area_filter) > 1
        warning('Caution: reflist for brain area > 1')
        if Opt.selectMostFrequentRef
            [r] = max(references(area_filter));
            ref_filter = [tetinfo.id] == r;
        end
    end

    tetList{area_cnt} = [tetinfo(area_filter & nonref_filter).id];
    refList{area_cnt} = [tetinfo(area_filter & ref_filter).id];

end
areas = uAreas;
