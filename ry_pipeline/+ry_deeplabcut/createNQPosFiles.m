function createNQPosFiles(rawDir, dataDir, animID, sessionNum, varargin)
% createNQPosFiles_new(rawDir, dataDir,animID,sessionNum, Opt.dioFramePulseChannelName)
%
% This function extracts POS information and saves data in the FF format.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Assumes position tracking WITH range and cm per pix already calculated in the pipeline.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% The function also assumes that there is a '*.time' folder in the current directory
% conaining time information about the session (from
% extractTimeBinaryFile.m).
%
%
% rawDir -- the directory where the raw dat folders are located
% dataDir -- the directory where the processed files should be saved
% animID -- a string identifying the animal's id (appended to the
% beginning of the files).
% sessionNum -- the session number (in chronological order for the animal)
% Opt.dioFramePulseChannelName -- dio channel used for pulsed frames (mcz added 12/09/16)
% Adapted from mcz_createNQPosFiles_new and createNQPosFiles
% Fixed by Roshan 4/8/2017
%
%  Ryan : re-adpated this code to accept my pipeline-filterframework rawpos for deeplabcut data.
%  The major feature is that it's more permissive of extra-tracking points and leds.
%
%  - Extra fields from DLC rawpos, like the model's sense of the points
%  statistical likelihood of the animal's position
%  
%  - List of indices that are considered valid in rawpos (useful if one works
%  with rawpos and this structure)
%
%  - Reorganized this code around a notion that a deeplabcut-icist can choose
%  to track more than just two points, and not even nessarily diodes! So i
%  dropped much of the "diode" terminology. To find a "one true position" (x,y)
%  tuple, it simply searches for the first pair of points to include
%  front/back in their names or left/right in their names

ip = inputParser;
ip.addParameter('dioFramePulseChannelName', []);  % default strobing channel not used
%ip.addParameter('posfilt', gaussian(30*0.5, 60)); % gaussian smoothing for velocity filter
ip.addParameter('posfilt', gaussian(30*0.05, 15)); % gaussian smoothing for velocity filter
ip.addParameter('midpoint', 0.5);                 % use average between front and back diodes
ip.addParameter('maxv', 400);                     % maximum velocity in cm/s
ip.addParameter('maxdevpoints', 0);
ip.addParameter('bounds', [0 0 ; 1292 964]);      % Opt.bounds of video
%ip.addParameter('maxpinterp', 1e100);             % allow interpolation of any number of points
%ip.addParameter('maxdinterp', 1e100);             % allow interpolation over any distance
ip.addParameter('reversex',       false);         % don't flip pos along x
ip.addParameter('reversey',       false);         % don't flip pos along y
%ip.addParameter('pinterp',        true);          % do interpolate
ip.addParameter('globalCentroid', false);
ip.addParameter('skipProc', true);
ip.parse(varargin{:})
Opt = ip.Results;

% 1/30/17 integrated vargin for posinterp
currDir = pwd;
cleanup = onCleanup(@() cd(currDir));
cd(rawDir);
epochTimes= getEpochs(1);
dayString = sprintf('%02i',sessionNum);

%%%%%%%%%%%%%%%%%%%
% create all rawpos per epoch
%%%%%%%%%%%%%%%%%%%

cd(dataDir);
if isempty(dir([animID 'rawpos' dayString '*-*.mat']));
    error('Must  run ry_deeplabcut.generateRawPosFile first')
end
rawpos = ndBranch.load(animID, 'rawpos','folder', dataDir,'simplefilter',sprintf('%02d-',sessionNum));
%%%%%%%%%%%%%%%%%%
% next, create pos
%%%%%%%%%%%%%%%%%%

if isempty(dir([animID 'pos' dayString '.mat'])) || ~Opt.skipProc
    disp('processing pos');
    epochNum= size(epochTimes,1);
    if epochNum > numel(rawpos{sessionNum})
        difference = char(string(setdiff(1:epochNum,1:numel(rawpos{sessionNum})))); 
        warning(sprintf('rawpos day %d missing epochs %s',sessionNum, difference));
        epochNum  = numel(rawpos{sessionNum});
    end


    pos={};
    for e=1:epochNum
        if ~isempty(rawpos{sessionNum}{e}) && ~isempty(rawpos{sessionNum}{e}.data)

            disp("Processing day " + sessionNum + " epoch " + e);
            disp("---------------------------------------------")

            pos{sessionNum}{e} = rawpos{sessionNum}{e};
            
           % interpolate any jumps
           % convert back to px for interpolation
           tmppos = pos{sessionNum}{e};
           if strcmp(tmppos.units,'cm')
                tmppos.data(:,2:end) = tmppos.data(:,2:end)./tmppos.cmperpixel;
                tmppos.units = 'px';
           end

           tmppos = ry_deeplabcut.posinterpSimple(tmppos, Opt);

           if strcmp(tmppos.units,'px')
               tmppos.data(:,2:end) = tmppos.data(:,2:end).*tmppos.cmperpixel;
               tmppos.direction_complex = tmppos.direction_complex .* tmppos.cmperpixel;
               tmppos.units='cm';
           end

           pos{sessionNum}{e} = tmppos;
           pos{sessionNum}{e} = ry_deeplabcut.addvelocity(pos{sessionNum}{e}, Opt.posfilt);% add smoothed velocity

           %TODO: add loess smoothed position

        else
            pos{sessionNum}{e}.data = [];
        end
        disp(newline)
    end
    % Ensure that rawpos actually reaches the final epoch
    if size(epochTimes,1) > numel(pos{sessionNum})
        pos{sessionNum}{size(epochTimes,1)} = {};
    end

    save([dataDir filesep animID 'pos' dayString '.mat'],'pos');

else
    disp('pos already processed');
end
