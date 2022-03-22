function instructions = placeAxes(instructions, axs) 
axisTags = string({axs.Tag});

counter = struct();
for ii = 1:numel(instructions)
    instruction  = instructions{ii};
    potentialMainObject = contains(instruction.type, ["point","vector","gridState"], 'IgnoreCase', true);
    edgeAxisObject      = contains(instruction.type, "Ax");
    if potentialMainObject && ~edgeAxisObject
        instruction.ax = axs(end);
        assert(strcmp(axs(end).Tag, 'main'));
    elseif edgeAxisObject
        if ~isfield(counter, instruction.type)
            counter.(instruction.type) = 0;
        end
        counter.(instruction.type) = counter.(instruction.type) + 1;
        T = string(split(instruction.type,"_"));
        instruction.axNum = counter.(instruction.type);
        axName = string(T(1)) + "_" + instruction.axNum;
        instruction.ax = axs(axisTags == axName);
    else
        error("Unreognized option")
    end
    instructions{ii} = instruction;
end
