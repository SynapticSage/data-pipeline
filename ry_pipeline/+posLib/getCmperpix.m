function cmperpix = getCmperpix(animID, dayepoch)
% 
% Check for cmperpix file in existing rawpos
rawpos = ndb.load(animID, 'rawpos', 'indices', dayepoch);
cmperpix = cellfetch(rawpos, 'cmperpixel');
if ~isempty(cmperpix.index)
    cmperpix = cmperpix.values{1};
    return;
end

% Check for cmperpix in  task
task = ndb.load(animID, 'task', 'indices', dayepoch);
task = ndb.unnest(task, 'maze', 'cmperpixel');
task = ndb.unnest(task, 'video', 'cmperpixel');
C = cellfetch(task,'cmperpixel');
if ~isempty(C.index)
    cmperpix = C.values{1};
    return
end

% For a cmperpix file
cmperpixFile = fullfile(rawdef(animID), sprintf('%scmperpix_%02d.txt', animID, sessionNum));
if exist(cmperpixFile,'file')
    cmperpix = readlines(cmperpixFile);
    cmperpix = str2double(cmperpix);
    return;
end
