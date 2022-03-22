
% Parameters
% ----------
animID   = 'RY16';
dayepoch = [36 2];
basepath = "/Volumes/GenuDrive/RY16_direct/RAW/";
transform = @(frame) imresize(...
    imadjust(frame,[0 0 0; .7 .7 .7],[]), ...
    'OutputSize', [800, 1024],...
    'Antialiasing',true) % arbitray function applied to cleanup or change frame ize


% Behavioral structs to potentially sample
% ----------------------------------------
ego = ndb.load(animID, 'egocentric', ...
    'indices', dayepoch,...
    'get', true);
decode =  deepinsightLib.preprocessDF(animID, dayepoch, ...
    basepath+'df_processed_RY16deepinsight36.mat',...
    'addStruct', ego);

%                                                               
% .    ,          |                        o    |               
% |    |,---.,---.|--- ,---.,---.    .    ,.,---|,---.,---.,---.
%  \  / |---'|    |    |   ||         \  / ||   ||---'|   |`---.
%   `'  `---'`---'`---'`---'`          `'  ``---'`---'`---'`---'
%                                                               

% Load a config file specifiying how to plot the video
% ----------------------------------------------------
posLib.plot.config.videoScript.AllVec
% Plot it
posLib.plot.behavior(animID, dayepoch, ego, instructions...
    ...,'outputCheckpoint', 0) ...
    ,'outputCheckpoint', 10e3, ...
    'outputName','~/Result_deepInsight/AllVec.mat'...
                    ,'Quality',100,'transform',transform);

% Load a config file specifiying how to plot the video
% ----------------------------------------------------
posLib.plot.config.videoScript.SpeedPosHeaddir_Decode;
posLib.plot.behavior(animID, dayepoch, decode, instructions...
    ,'outputCheckpoint', 0);
    %,'outputCheckpoint', 10e3, ...
    %'outputName','~/Result_deepInsight/AllVec.mat');
    
% Load a config file specifiying how to plot the video
% ----------------------------------------------------
posLib.plot.config.videoScript.SpeedPosHeaddir_Decode;
posLib.plot.behavior(animID, dayepoch, decode, instructions...
    %,'outputCheckpoint', 0);
    ,'outputCheckpoint', 5e3, ...
    'outputName','~/Result_deepInsight/SpeedPosHeaddir_Decode.mat'...
...%videoLib.writeFrames2Video('~/Result_deepInsight/SpeedPosHeaddir_Decode.avi',outFrame,...
                        ,'Quality',100,'transform',transform);

% Load a config file specifiying how to plot the video
% ----------------------------------------------------
posLib.plot.config.videoScript.SpeedPosHeaddir_Decode;
instructions = {headVecDec2, posDecodeVec, goalVec, headVec, headVecDec};
posLib.plot.behavior(animID, dayepoch, decode, instructions...
    %,'outputCheckpoint', 0);
    ,'outputCheckpoint', 10e3, ...
    'outputName','~/Result_deepInsight/SpeedPosHeaddir_Decode2.mat'...
                        ,'Quality',100,'transform',transform);


% Load a config file specifiying how to plot the video
% ----------------------------------------------------
posLib.plot.config.videoScript.SpeedPosHeaddir_withGoal;
posLib.plot.behavior(animID, dayepoch, decode, instructions...
    %,'outputCheckpoint', 0);
    ,'outputCheckpoint', 10e3, 't0', 30000, ...
    'outputName','~/Result_deepInsight/SpeedPosHeaddir_withGoal.mat');


%                                                         
% ,---.|         |             .    ,o    |               
% `---.|--- ,---.|--- ,---.    |    |.,---|,---.,---.,---.
%     ||    ,---||    |---'     \  / ||   ||---'|   |`---.
% `---'`---'`---^`---'`---'      `'  ``---'`---'`---'`---'
%                                                         
%
posLib.plot.config.videoScripts.cuemem();
posLib.plot.behavior(animID, dayepoch, decode, instructions...
    %,'outputCheckpoint', 0);
    ,'outputCheckpoint', 10e3, 't0', 30000, ...
    'outputName','~/Result_deepInsight/cumem.mat');



