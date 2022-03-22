function out = preprocessDF(animID, dayepoch, filename,varargin)
% This functoni takes in the path to a df file from deepinsight
% and preprocess it.

ip=inputParser;
ip.addParameter('method','linear');
ip.addParameter('swap',["|","_y"; "-", "_"]);
ip.addParameter('createCollapsedY', true);
ip.addParameter('roundFields',["startWell","stopWell","undefined","cuemem"]);
ip.addParameter('nearestFields',["headdir", "currentAngle"]);
ip.addParameter('addStruct',{});
ip.addParameter('addStructTimeField','postime');
ip.parse(varargin{:})
Opt = ip.Results;

joinchar = "_";

if ~exist(filename, 'file')
    error("Matfile %s not found!", filename)
end
M = matfile(filename);
if ~contains('time', fieldnames(M))
    error("Matfile does not contain time");
end
time = M.time;

pos = ndb.load(animID, 'pos', 'indices', dayepoch, 'get', true);
if iscell(pos)
    pos = nd.cat(pos,1,[],'removeEmpty', true);
end
videotime = pos.data(:,1);
videotime = videotime(~util.getduplicates_logical(videotime));

%% -----------------------------------------------------
% And we have to throw any dups out in the decoded stuff
%% -----------------------------------------------------
goodtimes = ~util.getduplicates_logical(time) & logical([false; ~(diff(time) == 0)])'

%% -------------------------------------------------
%% Get decode data from python deepinsight structure
%% -------------------------------------------------
switch Opt.method
case 'nearest'
    inter  = @(x) interp1(time(goodtimes),  x(goodtimes,:),  videotime, 'nearest');
case 'linear'
    inter  = @(x) interp1(time(goodtimes),  x(goodtimes,:),  videotime, 'linear');
end
% --------------------------------------
out = struct();

% --------------------------------------
% Fields in the root who are time length
% --------------------------------------
if all(~ismember(["actual", "predict", "loss"],fieldnames(M)))

    for subfield = string(fieldnames(M))'
        new_subfield = subfield;
        for i = 1:size(Opt.swap,1)
            new_subfield = replace(new_subfield,Opt.swap(i,1), Opt.swap(i,2));
        end
        Q = M.(subfield);
        try
            out.(lower(new_subfield)) = inter(Q);
        catch Exception
            disp(sprintf('Skipping %s', subfield))
            if ~isequal(subfield,"Properties")
                keyboard
            end
        end
    end

end
% Fields in nested stCase in which data has not been flattened and is
% hierarchical struct
% -------------------------------------------------------------------
for field = ["actual", "predict", "loss"]
    if ~ismember(field, fieldnames(M))
        continue
    end
    Q = M.(field);
    for subfield = string(fieldnames(Q))'
        new_subfield = subfield;
        for i = 1:size(Opt.swap,1)
            new_subfield = replace(new_subfield,Opt.swap(i,1), Opt.swap(i,2));
        end
        out.(lower(field + joinchar +  new_subfield)) = inter(Q.(subfield));
    end
end


%% Add struct info from my existing matfiles?
%% ------------------------------------------
if ~isempty(Opt.addStruct)
    X = Opt.addStruct;
    timefield = X.(Opt.addStructTimeField);
    dups = util.getduplicates_logical(timefield);
    switch Opt.method
    case 'nearest'
        inter =  @(x) interp1(timefield(~dups,:), x(~dups,:), videotime, 'nearest');
    case 'linear'
        inter  = @(x) interp1(timefield(~dups,:), x(~dups,:), videotime, 'linear');
    end
    if iscell(X)
        X = nd.cat(X, 1);
    end

    % Place X fields into decode for convenience
    for field = string(fieldnames(X))'
        if field == Opt.addStructTimeField
            continue
        end
        try
            out.(field) = inter(X.(field));
        catch E
            out.(field) = X.(field);
        end
    end
end


if Opt.createCollapsedY
    fields = string(fieldnames(out));
    fields = fields(contains(fields, "_y"));

    splitresult = split(fields, "_y");

    splitresult = sortrows(splitresult, 1:2);
    varTypes     = splitresult(:,1);
    varNums      = splitresult(:,2);

    for varType = unique(varTypes)'
        filt = varTypes == varType;
        collapse = zeros(size(out.(varType + "_y1"),1), sum(filt));
        for element = splitresult(filt, :)'
            collapse(:, str2double(element(2))) = out.(join(element, "_y"));
        end
        out.(varType + "_Y") = collapse;
    end
end

if ~ismember("time", string(fieldnames(out)))
    out.time = videotime;
end
