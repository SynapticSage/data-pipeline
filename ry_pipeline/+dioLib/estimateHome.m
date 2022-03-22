function [home, arena] = estimateHome(dio, maze)
% ESTIMATEHOME estimates the home and arena well from the mode statistic of wells

dio = dio(ismember(dio.num, maze.dio.cue),:); % Get the cues given
modalcue = mode(dio.num); % Find the mode
home  = maze.ordering.platforms( ismember(maze.dio.cue, modalcue)); % Set mode to home
arena = maze.ordering.platforms(~ismember(maze.dio.cue, modalcue)); % Set non-mode to arena
