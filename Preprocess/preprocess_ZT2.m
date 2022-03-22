animID     = 'ZT2';

%% PATHS, FOLDERS, METADATA
%% ========================
% PATH
addpath(genpath('~/Code/pipeline'))
addpath(genpath('~/Code/projects/goalmazebehavior'))

% FOLDER 
% -------
root   = '~/Data/Raw';
expDir = fullfile(root, 'SingleDayExpt')
%expDir = fullfile(root, 'ry_GoalCoding_Project');

% Animal specific files
rawDir = [expDir  filesep animID];
%[dayDirs, sessionList, sessionIndex] = ry_selectDays(rawDir, 34);
%dataDir = [expDir filesep [animID '_experiment'] filesep animID '_direct' filesep];
dataDir = [expDir filesep animID '_direct' filesep];

% Config file
% -----------
configFile =  '~/Configs/general-64tet/ZT2_withAreaTags.trodesconf';

% Tetrode metadata
% ----------------
[hpc, pfc] = deal(1, 2);
[tetStruct, areas, tetList, refList] = ry_getAreasTetsRefs('configFile', configFile, 'removeAreas', [ "SuperDead" ]);
nTets = max(cellfun(@max, tetList));
%% DAY INDEPENDENT (cellinfo, tetinfo)
%% ===================================
disp('Creating cell & tet info structures')

% Initialize marker structures
createtetinfostruct(dataDir,animID);
mcz_createcellinfostruct(dataDir,animID); 

% Describe tetrodes
sj_addtetrodelocation(dataDir,    animID, tetList{hpc}, 'CA1');
sj_addtetrodelocation(dataDir,    animID, tetList{pfc}, 'PFC');
sj_addtetrodedescription(dataDir, animID, refList{hpc},  'CA1Ref');
sj_addtetrodedescription(dataDir, animID, refList{pfc},  'PFCRef');
%sj_addtetrodedescription(dir1,prefix,riptetlist,'riptet'); 
sj_addcellinfotag2(dataDir,animID); 

