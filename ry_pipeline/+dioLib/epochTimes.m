function [starts, stops] = epochTimes(dio)
% Epoch start and stops as computed by the first and last dio event

dio = sortrows(dio,["day","epoch","time"]);
epochStarts = [1; diff(dio.epoch)] > 0;
starts = table2array(dio(epochStarts, 'time'));
if nargout == 2
    epochStops  = [diff(dio.epoch); 1] > 0;
    stops  = table2array(dio(epochStops, 'time'));
end
