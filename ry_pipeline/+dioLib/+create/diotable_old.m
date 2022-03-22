function diotable(dio, mode)

if nargin == 1
    mode = "dayepoch";

% Label dio struct and collect structs
structs = []
switch mode
    case "dayepoch"
        for iEpoch = 1:numel(dio)
            dioep = dio{iEpoch};
            for iDio = numel(dio{iEpoch})
                io = dio{iEpoch}{iDio};
                if isempty(io)
                    continue
                end
                io.day = iDay;
                io.epoch = iEpoch;
                io = explodeIOstruct(io);
                structs = [structs, io];
            end
        end
    case "day"
        for iDay = 1:numel(dio)
        for iEpoch = 1:numel(dio{day})
            for iDio = numel(dio{day}{epoch})
                io = dio{iDay}{iEpoch}{iDio};
                if isempty(io)
                    continue
                end
                io.epoch = iEpoch;
                io = explodeIOstruct(io);
                structs = [structs, io];
            end
        end
        end
    case "ios"
        for iDio = 1:numel(dio)
            io = dio{iDio};
            if isempty(io)
                continue
            end
            io = explodeIOstruct(io);
            structs = [structs, io];
        end
end

% Convert struct into tidy data table
primordialTable = struct2table(structs);

diotable = table();
for variable = primordialTable.Properties.VariableNames
    data = primordialTable.(variable{1});
    data = cellfun(@(x) x(:), data, 'UniformOutput', false);
    diotable.(variable{1}) = cat(1,data{:});
end

% Final munge steps 
id = diotable.id;
diotable.idnum = str2double(id.extractAfter(4).strip())

    function explodeIOstruct(io)
        io.direction = repmat(string(io.direction), 1, numel(io.time));
        io.id = repmat(string(io.id), 1, numel(io.time));
