
%  ____                      _   ____           
% / ___| _ __   ___  ___  __| | |  _ \ ___  ___ 
% \___ \| '_ \ / _ \/ _ \/ _` | | |_) / _ \/ __|
%  ___) | |_) |  __/  __/ (_| | |  __/ (_) \__ \
% |____/| .__/ \___|\___|\__,_| |_|   \___/|___/
%       |_|                                     
%  _   _                _ ____  _      
% | | | | ___  __ _  __| |  _ \(_)_ __ 
% | |_| |/ _ \/ _` |/ _` | | | | | '__|
% |  _  |  __/ (_| | (_| | |_| | | |   
% |_| |_|\___|\__,_|\__,_|____/|_|_|   

headVec = struct('type',  'vector',...
                'field1', 'actual_position', 'x', 1, ...
                'field2','actual_position_y' , 'y', 1, ...
                'field3', 'headVec',...
               'u', 1, 'scale', {{1}},...
               'varargin',...
    {{'color','green',...
    'linewidth',1,...
    'linestyle','-',...
    'marker','o',...
    'markersize',4}});

headVecDec = struct('type',  'vector',...
                'field1', 'actual_position',   'x', 1, ...
                'field2','actual_position_y' , 'y', 1, ...
                'field3', 'predict_head_direction',...
               'theta', 1, 'scale', {{10}}, ...
               'thetaShift', pi/2, ...
               'varargin',...
    {{'color','green',...
    'linewidth',2,...
    'linestyle',':',...
    'marker','o',...
    'markersize',4}});

headVecDec2 = struct('type',  'vector',...
                'field1', 'predict_position',   'x', 1, ...
                'field2','predict_position_y' , 'y', 1, ...
                'field3', 'predict_head_direction',...
               'theta', 1, 'scale', {{10}}, ...
               'thetaShift', pi/2, ...
               'varargin',...
    {{'color','green',...
    'linewidth',0.5,...
    'linestyle',':',...
    'marker','o',...
    'markersize',4}});

decode.predict_pos_dist = [decode.predict_position-decode.actual_position,...
                           decode.predict_position_y-decode.actual_position_y];
posDecodeVec = struct('type',  'point',...
                ...'field1', 'actual_position',    'x', 1, ...
                ...'field2', 'actual_position_y' , 'y', 1, ...
                'field3', 'predict_position',    'x', 1, ...
                'field4', 'predict_position_y' ,   'y', 1, ...
               'varargin',...
    {{'color','red',...
    'markeredgecolor','white',...
    'markerfacecolor','red',...
    'linewidth',3,...
    'linestyle',':',...
    'marker','o',...
    'markersize',8}});
%posDec = struct('type',  'point',...
%                'field1', 'predict_position', 'x', 1, ...
%                'field2', 'predict_position_y' , 'y', 1, ...
%               'varargin',...
%    {{'color','red',...
%    'linewidth',3,...
%    'linestyle',':',...
%    'marker','o',...
%    'markersize',4}});

speed = struct('type',  'magnitudeAx',...
               'field1', 'actual_speed',...
               'val', 1, 'maxval',{{40}},...
               'varargin',...
    {{'color','cmap',...
    }});
speedDec = struct('type',  'magnitudeAx_line',...
               'field1', 'predict_speed',...
               'val', 1,...
               'varargin',...
    {{'color','black',...
    'linewidth',3,...
    'linestyle',':',...
    'marker','o',...
    'markersize',4}});
goalVec = struct('type',  'vector',...
               'field1', 'pos',...
               'x', 1, 'y', 2, ...
               'field2', 'currentGoalVec',...
               'u', 1, 'scale', {{1}}, ...
               'varargin', ...
    {{'color',[0 1 1],...
    'LineWidth',2.5,...
    'LineStyle',':',...
    'Marker','o',...
    'MarkerSize',4}});
egoVec = struct('type',  'polarAx',...
               'field1', 'actual_goal_velocity_angle',...
               'u', 1, 'scale', {{1}}, ...
               'varargin', ...
    {{'color','black',...
    'LineWidth',3,...
    'LineStyle','-',...
    'Marker','o',...
    'MarkerSize',4}});
egoVecDec = struct('type',  'polarAx',...
               'field1', 'actual_goal_velocity_angle',...
               'u', 1, 'scale', {{1}}, ...
               'varargin', ...
    {{'color','black',...
    'LineWidth',3,...
    'LineStyle',':',...
    'Marker','o',...
    'MarkerSize',4}});
egoVecDec = struct('type',  'gridState',...
               'field1', 'dec_end_well',...
               'u', 1, 'scale', {{1}}, ...
               'varargin', ...
    {{'color','black',...
    'LineWidth',3,...
    'LineStyle',':',...
    'Marker','o',...
    'MarkerSize',4}});

instructions = {posDecodeVec, goalVec, headVec, headVecDec};
