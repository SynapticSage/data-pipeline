function [validated, validationTable] = ry_validateAndFixFolder(dayDir, varargin)
% Checks if folder has one *.stateScriptLog per epoch and if each trodesComment
% for each epoch only one start and one stop

ip = inputParser;
istruefalse = @(x) islogical(x) || (x == 1 || x == 0);
ip.addParameter('fix', false, @istruefalse)
ip.addParameter('pruneUnnecessaryComments', false);
ip.parse(varargin{:});
opt = ip.Results;

currdir = pwd;
cleanup = onCleanup(@() cd(currdir));
cd(dayDir)

%% Validate the files! (and fix if reuquested)
files = dir('*.videoTimeStamps');
validateStatescript   = true(numel(files),1);
fixedStatescript      = true(numel(files),1);
validateTrodesComment = true(numel(files),1);
fixedTrodesComment    = true(numel(files),1);

cnt = 0;
for file  = files'
    
    name = file.name;
    cnt = cnt + 1;
    filenames(cnt) = string(replace(name, '.videoTimeStamps', ''));

    % stateScriptLog files exist
    statescriptFile = filenames(cnt) + '.stateScriptLog';
    if ~exist(statescriptFile,'file')
        validateStatescript(cnt) = false;
        % If nonexistent, touch one
        if opt.fix
            fid=fopen(stateScriptLog,'a');
            fclose(fid);
            fixedStatescript(cnt) = true;
        end
    end

    % Check that  trodesComment files look alright
    trodesCommentFile = filenames(cnt) + ".trodesComments";
    if ~exist(trodesCommentFile,'file')
        validateTrodesComment(cnt) = false;
        fixedTrodesComment(cnt)    = false;
    else
        if startendsTooNumerous(trodesCommentFile)
            pruneMiddleStartEnds(trodesCommentFile)
        end
    end

    startEndCorr = correctMissingStartOrEnd(trodesCommentFile);
    
    if opt.pruneUnnecessaryComments
        pruneUnnecessaryComments(trodesCommentFile);
    end
end

%% Compute overall validation picture
validation = table(validateStatescript, validateTrodesComment,...
                   'VariableNames',  {'statescript','comments'});
fixed = table(fixedStatescript, fixedTrodesComment,...
              'VariableNames',  {'statescript','comments'});
validationTable = table(filenames(:), validation, fixed,...
                        'VariableNames',  {'filenames', 'validation','fixed'});
validated = all(table2array(validation),'all'); % We had total validation if all files passed the test

                                                                           
% ,---.               o,---.o                        |                  ,---.
% `---.,---.,---.,---..|__. .,---.    ,---.,---.,---.|--- ,---.    ,---.|__. 
%     ||   ||---'|    ||    ||        `---.|   ||    |    `---.    |   ||    
% `---'|---'`---'`---'``    ``---'    `---'`---'`    `---'`---'    `---'`    
%      |                                                                     
%                     
% ,---.o              
% |__. ..  ,,---.,---.
% |    | >< |---'`---.
% `    `'  ``---'`---'
%                     
% -----------------------------------------------------------------------
function answer = startendsTooNumerous(trodesCommentFile)
% Returns yes if there are too many starts stops in a trodes comment file
    answer = false;
    contents = string(fileread(trodesCommentFile));
    contents = contents.splitlines();
    if sum(contains(contents,"start")) > 1
        answer = true;
    end
    if sum(contains(contents, "end")) > 1
        answer = true;
    end

% -----------------------------------------------------------------------
function answer = pruneUnnecessaryComments(trodesCommentFile)
% Prunes any messages which arent epoch start or epoch stop

    answer = false;
    contents = string(fileread(trodesCommentFile));
    contents = contents.splitlines();

    firststart = find(contains(contents,"start"),1,'first');
    lastend    = find(contains(contents, "end"),1,'last');

    contents = [contents(firststart); contents(lastend)];
    contents = num2cell(contents);
    for i = 1:numel(contents)
        C = contents{i};
        C = C.split(" ");
        C(C=="") = [];
        num_portion = find(cellfun(@(x) all(isstrprop(x, 'digit')), num2cell(C)), 1, 'first');
        epoch_portion = find(cellfun(@(x) contains(x,'epoch'), num2cell(C)), 1, 'first');
        startend_portion = find(cellfun(@(x) contains(x,["start", "end"]), num2cell(C)), 1, 'first');
        C = C([num_portion, epoch_portion, startend_portion]);
        C = join(C, " ");
        contents{i} = C;
    end
    contents = cat(1, contents{:});
    contents = join(contents, newline);

    fid = fopen(trodesCommentFile, 'w');
    if fid ~= -1
        fwrite(fid, contents);
        fclose(fid);
    end

% -----------------------------------------------------------------------
function changeIt = correctMissingStartOrEnd(trodesCommentFile)
% Fixes a missing start or end line in a comment

    contents = string(fileread(trodesCommentFile));
    contents = contents.splitlines();

    changeIt = ~any(contains(contents,"epoch start")) || ~any(contains(contents, "epoch end"));
    if changeIt
        newContents = generateStartsStops(trodesCommentFile)
        fid = fopen(trodesCommentFile, 'w');
        if fid ~= -1
            fwrite(fid, newContents);
            fclose(fid);
        end
    end


function outStr = generateStartsStops(file)
% Generates starts and stops without pauses

    timeStamps = readCameraModuleTimeStamps(file);
    if i>1 && (timeStamps(1)<lastEnd || reset)
        outStr = char(outStr,'time reset');
        reset = 1;
    end
    clockrate = 30e3;
    startEpoch = timeStamps(1);
    endEpoch = timeStamps(end);
    startEpoch = startEpoch*clockrate;
    endEpoch = endEpoch*clockrate;
    outStr = string(sprintf('%0.0f %s',startEpoch,'epoch start')) + newline + ...
             string(sprintf('%0.0f %s',endEpoch,'epoch end'));

% -----------------------------------------------------------------------
function pruneMiddleStartEnds(trodesCommentFile)
% Fixes an issue with trodesComment files where recording is start/stopped for
% more than a second. In the automated comment creation, this will make it so
% an epoch will have multiple starts ends. We can just prune the iner starts
% ends to make it work.

    %  Before we fix anything, let's backup
    copyfile(trodesCommentFile, trodesCommentFile + ".fix.bak_" + date());

    % Get  file contents
    contents = string(fileread(trodesCommentFile));
    contents = contents.splitlines();
    contents = contents(~(contents == "")); % Toss out empty lines
    if any(contents == "time reset")
        assert(all(find(contents == "time reset") == 1), 'Time reset not at beginning  of file')
        timereset = true;
        contents(contents == "time reset") = [];
    else
        timereset = false;
    end
    contents = contents.split(" ");

    ROW = 1;
    COL = 2;
    starts = any(contents == "start", COL);
    ends   = any(contents == "end",   COL);

    firstStart = find(starts, 1, 'first');
    lastEnd    = find(ends,   1, 'last');

    % Remove all startend lines who are the first and last
    starts(firstStart) = false;
    ends(lastEnd) = false;
    contents(starts | ends,:) = [];

    % Now we gotta reconstruct the file text and write the conntents
    contents = contents.join(" ", COL);
    if timereset
        contents = ["time reset"; contents];
    end
    contents = contents.join(newline, ROW);
    fid = fopen(trodesCommentFile, 'w');
    fwrite(fid, contents);
    fclose(fid)
