%   ____ _               _      _____     _       _     
%  / ___| |__   ___  ___| | __ |_   _| __(_) __ _| |___ 
% | |   | '_ \ / _ \/ __| |/ /   | || '__| |/ _` | / __|
% | |___| | | |  __/ (__|   <    | || |  | | (_| | \__ \
%  \____|_| |_|\___|\___|_|\_\   |_||_|  |_|\__,_|_|___/
%                                                       
%                          
% Script that checks the dio and trial events in the video

% FLAGS
% =====
% Trial on events
onEvents = {
{},... Sequence of on keywords-value pairs for the table
{},...
};
% Trial off events
offEvents = {
{},... Sequence of on keywords-value pairs for the table
{},...
};
% Padding
padding = [-0.5, 0.5];

% Obtain tables
% -------------
