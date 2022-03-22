function T = insertTableValue(T, where, what, varargin)
% Inserts into T what at where
ip = inputParser;
ip.addParameter('where', 'time'); % time or index
ip.addParameter('what', ["state"]); % time or index
ip.parse(varargin{:})
Opt = ip.Results;

groups = findgroups(T.day, T.num);
uGroups = unique(groups);

newTab = table();
for g = uGroups'
    t = T(g,:);
    if strcmp(Opt.where, 'time')
        t = sortrows(t,'time');
    end
    for splitter = where(:)'
        if strcmp(Opt.where,'time')
            filt = t.time <  splitter;
            if sum(filt)
                splitLoc = find(filt,1,'last');
            else
                splitLoc = 0;
            end
            time = splitter;
        else
            splitLoc = splitter;
            time = nan;
        end
        t = insert(t, splitLoc, what, time, Opt);
    end
    newTab = [newTab;  t];
end

function t = insert(t, splitLoc, what, time, Opt)

    a = t(1:splitLoc, :);
    b = t(min(splitLoc+1,height(t)):end, :);

    if isempty(a)
        value = b(1,:);
    else
        value = a(end,:);
    end
    value = value(1, :);
    value(1,:) = array2table(nan(1,width(value)));
    value.time  = time;
    value(1,cellstr(Opt.what)) = array2table(what);

    t = [a; value; b];
