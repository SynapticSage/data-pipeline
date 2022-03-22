function task = taskAddDescriptor(task, fields, values)
% adds descriptor fields to task struct

if istable(values) || isstruct(values)
    fcnt = 0;
    for field = fields(:)'
        fcnt = fcnt + 1;
        task.(field) = values.(field);
    end
else
    fcnt = 0;
    for field = fields(:)'
        fcnt = fcnt + 1;
        task.(field) = values(fcnt);
    end
end
