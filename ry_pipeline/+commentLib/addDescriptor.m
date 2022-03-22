function values = addDescriptor(file, fields, values, backupState)
% This function automates adding description fields to trodes
% comment files who represent a single epoch

[path,name,ext] = fileparts(file);

if iscellstr(values)
    values = string(values);
end

% Read in current comment file
fid = fopen(file, 'r');
assert(fid ~= -1, sprintf('file=%s missing', file));
lines = string([]);
lines(end+1) = string(fgetl(fid));
while true
    val = fgetl(fid);
    if val == -1
        break
    else
        lines(end+1) = string(val);
    end
end
fclose(fid);

% Last timestamp
startLine = contains(lines, "start");
tmp = squeeze(split(lines(startLine), " "));
timestamp = str2double(tmp(1)) + 1;
clear tmp

% Compute what the newlines should be
newlines  = [];
fcount = 0;
for field = fields
    fcount = fcount  + 1;
    if istable(values)
        val = string(table2array(values(:,field)));
    elseif isstruct(values)
        val  = values.(field);
    elseif isstring(values)
        val  = values(fcount);
    end
    if ismissing(val)
        continue
    end
    newlines = [newlines, join([string(timestamp), field, val], " ")];
    timestamp = timestamp + 1;
end

% Throw out any newlines that verbatim match old lines
newlines = newlines(~ismember(newlines,  lines));

% Write any unique newlines
if ~isempty(newlines)

    if nargin == 3  || backupState
        copyfile(file, name+ext+'.desc.bak_'+date);
    end

    % Write the new comment file
    newfile = name + ext;
    fid = fopen(newfile,'w');
    fprintf(fid,'%s\n', lines(1));
    for newline = newlines(1:end)'
        if isempty(newline)
            continue
        end
        fprintf(fid,'%s\n', newline);
    end

    for line = lines(2:end-1)'
        if isempty(line)
            continue
        end
        fprintf(fid,'%s\n', line);
    end

    fprintf(fid,'%s\n', lines(end));
    fclose(fid);
end
