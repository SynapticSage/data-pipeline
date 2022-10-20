function [processFolders, sessionList, sessionIndex] = ry_selectDays(animalRawFolder, starts, stops, varargin)
% RY_SELECTANIMALRAWFOLDER finds all folders in the start stop ranges provided
%
% animalRawFolder : str char
%
% start : vector 1 X N (optional)
%   start of session number ranges to grab
%
% stop : vector 1 x N (optional)
%   stop of session number ranges to grab

ip = inputParser;
ip.addParameter('session', 'infer'); % {infer} | prefix
ip.parse(varargin{:})
Opt = ip.Results;

animalRawFolder = string(animalRawFolder);

folders = dir(animalRawFolder);
if isempty(folders)
    error("folders empty!")
end
foldernames = string({folders.name});
foldernames = foldernames(([folders.isdir]));
foldernames = foldernames(contains(foldernames,'_'));

if nargin < 2
    foldernamesplit = split(foldernames','_');
    sessions = foldernamesplit(:,1);
    sessions = str2double(sessions);
    starts = min(sessions);
    stops  = max(sessions);
elseif nargin < 3
    foldernamesplit = split(foldernames','_');
    sessions = foldernamesplit(:,1);
    sessions = str2double(sessions);
    stops = max(sessions);
end

processFolders = string([]);
sessionList = [];
sessionIndex = [];
dayCnt = 0;
for foldername = foldernames
    dayCnt = dayCnt+1;
    foldersplit = split(foldername,'_');
    included = false;
    session = str2num(foldersplit(1));
    for iRange = 1:numel(starts)
        start = starts(iRange);
        stop  = stops(iRange);
        if session >= start && session <=stop
            included = true;
        end
    end
    if included
        processFolders = [processFolders join(foldersplit, '_')];
        sessionList = [sessionList session];
        sessionIndex = [sessionIndex, dayCnt];
    end
end

sessionIndex = sessionIndex - min(sessionIndex) + 1;
