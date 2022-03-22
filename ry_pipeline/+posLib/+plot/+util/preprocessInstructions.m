function [instructions, iTable] = preprocessInstructions(beh, instructions, varargin)
% Converts an instruction cell to a list of points or vectors

ip = inputParser;
ip.addParameter('resize', []); % if video is used and frame is resized, then that is done here
ip.addParameter('cmperpix', []); % if video is used and frame is resized, then that is done here
ip.parse(varargin{:})
Opt = ip.Results;

% --------------------------
% Creat default instructions
% --------------------------
% GRIDSTATE
gridDefault = inputParser;
for field = ["type", "obj", "position", "color"]
    gridDefault.addParameter(field, []);
end
for field = ["width", "height", "radius"]
    gridDefault.addParameter(field, 4); % 4 centimeter default
end
gridDefault.addParameter('showText', false);
gridDefault.addParameter('varargin',{});

% POINT
pointDefault = inputParser;
pointDefault.addParameter('type',[]);
pointDefault.addParameter('obj',[]);
pointDefault.addParameter('x',[]);
pointDefault.addParameter('y',[]);
pointDefault.addParameter('varargin',{});

% VECTOR
vectorDefault = inputParser;
vectorDefault.addParameter('type',[]);
vectorDefault.addParameter('obj',[]);
vectorDefault.addParameter('x',[]);
vectorDefault.addParameter('y',[]);
vectorDefault.addParameter('u',[]);
vectorDefault.addParameter('v',[]);
vectorDefault.addParameter('varargin',{});

% MAGNINTUDE
magDefault = inputParser;
magDefault.addParameter('type',[]);
magDefault.addParameter('obj',[]);
magDefault.addParameter('axNum',1); % id number of the mag axis object
magDefault.addParameter('val',[]);
magDefault.addParameter('maxval',[]);
magDefault.addParameter('varargin',{});

% MAGNINTUDE Line Element
magLEDefault = inputParser;
magLEDefault.addParameter('type',[]);
magLEDefault.addParameter('obj',[]);
magLEDefault.addParameter('axNum',1); % id number of the mag axis object
magLEDefault.addParameter('val',[]);
magLEDefault.addParameter('maxval',[]);
magLEDefault.addParameter('varargin',{});

% POLAR Vector
polarVecDefault = inputParser;
polarVecDefault.addParameter('type',[]);
polarVecDefault.addParameter('obj',[]);
polarVecDefault.addParameter('axNum',1); % id number of the mag axis object
polarVecDefault.addParameter('theta',[]);
polarVecDefault.addParameter('r',[]);
polarVecDefault.addParameter('r0',{});

% POLAR Point Object
%
% -------------End of plot atom/object default arguments -----------------

% =======================
% Preprocess instructions
% =======================
% Iterate through each instruction and enumerate what sould be theree
iTable = table();
for ii = 1:numel(instructions)

    instruction = instructions{ii};
    singularFields = string([]);

    % GENERAL INSTRUCTION PREPROCEESS
    for field = string(fieldnames(instruction))'

        outputVariableToFill = ismember(field, ["x", "y", "u", "v", "val", "maxval", "theta", "r", "r0", "scale", "state", "gridTable", "height", "width", "radius", "pos"]);
        inputVariableToRead = contains(field, 'field');

        if outputVariableToFill
            hardGivenFieldValue = iscell(instruction.(field));
            if hardGivenFieldValue
                if numel(instruction.(field){1}) == 1
                    singularFields(end+1) = field;
                    instruction.(field) = instruction.(field){1};
                else
                    instruction.(field) = instruction.(field){1};
                end
            else % otherwise, user is saying which columns to read
                column              = instruction.(field);
                instruction.(field) = beh.(behField)(:,column);
            end

            pixelRescaledVar = ismember(field, posLib.plot.config.outputVars.pixelRescaled);
            if pixelRescaledVar
                instruction.(field) = instruction.(field) * Opt.resize/Opt.cmperpix;
            end
        elseif inputVariableToRead
            behField = instruction.(field);
        end

    end

    %% --------------------------------
    %% VECTOR OBJECT SPECIAL PREPROCESS
    %% --------------------------------
    if instruction.type == "vector" && isfield(instruction,'theta')
        if isfield(instruction,'thetaShift')
            instruction.theta = instruction.theta + instruction.thetaShift;
        end
        [instruction.u, instruction.v] = deal(sin(instruction.theta), cos(instruction.theta));
        if isfield(instruction, 'r')
            instruction.u = instruction.u .* instruction.r;
            instruction.v = instruction.v .* instruction.r;
        end
    end
    if instruction.type == "vector" && isfield(instruction,'u')
        if ~isfield(instruction,'v') || isempty(instruction.v)
            err = 0.1
            if ~isreal(instruction.u) 
                [instruction.u, instruction.v] = deal(...
                    real(instruction.u),...
                    imag(instruction.u));
            elseif range(instruction.u) > 2*pi - err && range(instruction.u) < 2*pi + err
                [instruction.u,instruction.v] = deal(...
                    cos(instruction.u),...
                    sin(instruction.u));
            else
                instruction.u = mod(instruction.u,2*pi);
                [instruction.u,instruction.v] = deal(...
                    cos(instruction.u),...
                    sin(instruction.u));
            end
        end
        if isfield(instruction,'scale') && ~isempty(instruction.scale)
            [instruction.u,instruction.v] = deal(instruction.u .* instruction.scale, instruction.v .* instruction.scale);
        end
    end

    %% --------------------------------
    %% GENERAL DEFAULT ARG FILL-INS
    %% --------------------------------
    % Fill out any instruction details not given
    switch instruction.type
        case 'point'
            parseObj = pointDefault;
        case 'vector'
            parseObj = vectorDefault;
        case 'magnitudeAx_bar'
            parseObj = magDefault;
        case 'magnitudeAx_line'
            parseObj = magLEDefault;
        case 'polarAx_line'
            parseObj = polarVecDefault;
        case {'wellGridState', 'positionGridState'}
            parseObj = gridDefault;
    end
    parseObj.KeepUnmatched = true;
    parseObj.parse(instruction);
    instruction  = nd.merge(parseObj.Results,...
                            parseObj.Unmatched);

    %% --------------------------------
    %% "WELL"/FIXED GRID STATE 
    %% --------------------------------
    isStaticGridObject = ismember(instruction.type,...
        ["gridState","gridStateAx", "wellGridState"]);
    if isStaticGridObject
        if ~isfield(instruction,'possibleStates')
            instruction.possibleStates = unique(round(instruction.state));
        end
        % Statics use grid table objects
        if isfield(instruction, 'gridTable')
            stateCount = numel(instruction.gridTable);
            for g  = 1:stateCount
                %fields = setdiff(["left","right","up","down","center_x","center_y","height", "width","radius"], fieldnames(instruction));
                fields = ["left","right","up","down","center_x","center_y","height", "width","radius"];
                for field = fields
                    if ~isfield(instruction.gridTable(g), field)
                        continue
                    end
                    instruction.gridTable(g).(field) = instruction.gridTable(g).(field) * Opt.resize/Opt.cmperpix;
                end
            end
        end
    end

    %% --------------------------------
    %% "POSITION"/DYNAMIC GRID STATE 
    %% --------------------------------
    isDynamicGridObject = ismember(instruction.type,...
        "positionGridState");
    if isDynamicGridObject
        % Broadcast each field to the proper size
        fields = ["width", "height", "radius"];
        for field = fields
            if ~isequal(size(instruction.(field)), size(instruction.state))
                instruction.(field) = bsxfun(@times, ...
                    instruction.(field), ...
                    ones(size(instruction.state)));
            end
        end
        if ~isfield(instruction, 'label')
            instruction.label = string(1:size(instruction.state,2));
        elseif ~isstrting(instruction.label)
            instruction.label = string(instruction.label);
        end
        keyboard
        if ~isfield(instruction, 'color') || isempty(instruction.color)
            cm = colormap;
            nColors = size(cm,1);
            for col = 1:size(instruction.state, 2)
                values = instruction.state(:, col);
                D = discretize(values,...
                    linspace(min(values), max(values), nColors));
                instruction.color(:, col, :) = cm(D,:);
            end
        else
            if size(instruction.color, 1) == size(instruction.state)
                %broadcast modes
                if size(instruction.color, 2) == size(instruction, 2)
                    instruction.color = bsxfun(@times, instruction.color, ones(size(instruction.state)));
                else
                    instruction.color = bsxfun(@times, instruction.color, ones(size(instruction.state,1), 3, size(instruction.state,2)));
                    instruction.color = permute(instruction.color, [1 3 2]);
                end
            elseif size(instruction.state,2) == size(instruction.color,3)
                newColorMatrix = zeros([size(instruction.state), 3]);
                % value lookup mode
                nStates = size(instruction.state, 3);
                nValues = size(instruction.state, 1);
                for state = 1:nStates
                    values = instruction.state(:, state);
                    D = discretize(values, linspace(min(values), max(values), nStates));
                    newColorMatrix(:, state, :) = instruction.color(D, :, state);
                end
            end
        end
    end

    % ----------------------------------------------------------------
    % Create iTable: used for tracking the axse of instruction objects
    % ----------------------------------------------------------------
    type = string(instruction.type);
    if isfield(instruction,'axNum')
        axNum = instruction.axNum;
    else
        axNum = nan;
    end
    iTable = [iTable;...
              table(type,axNum)];
    instructions{ ii } = instruction;
end

% --------------------------------------------
% Number each element sharing an axis and type
% --------------------------------------------
groups = findgroups(categorical(iTable.type),iTable.axNum);
iTable.num = nan(height(iTable),1);
for group = unique(groups)'
    filt = groups == group;
    num = cumsum(filt(filt==1));
    iTable(filt,:).num = num;
end
