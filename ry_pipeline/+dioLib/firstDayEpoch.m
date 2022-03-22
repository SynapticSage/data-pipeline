function D = firstDayEpoch(dio)
% Takes a diotable and finds the first entrry per dayepoch

g = findgroups(dio.day, dio.epoch);

filt = [1; diff(g)] ~= 0;
D = dio(filt,:);
