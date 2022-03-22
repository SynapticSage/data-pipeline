%  |_   _(_)_ __  ___ 
%    | | | | '_ \/ __|
%    | | | | |_) \__ \
%    |_| |_| .__/|___/
%          |_|        
% Readability / Code Style / Good coding practices
% -------------------------------------------------
%
% Good practice makes it easier for to spot errors. Good habits help in the long run.
%
% 1.If you make a new section of code, put comment headers on that section.
% (Basically wherever it is natural to put separate code with an empty space to
% keep psychologically different pieces apart.)
%
% 2. Whenever you refer to an object with this many characters, 
%
%       callback{session}{epoch}.perf.table(row,:).time
%
% create a shortcut variable for it instead. Token(s) evaluating into an object
% are best when less than 30 characters, when possible for readability. I star
% sections with these issues below. (*)
%
% Table indexing
% --------------
%
% Table objects are 2D, so to get a fullrow of the table, you have to do,
%
%       perf.table(row,:)
%
% to return a row with all columns.
% --------------------------------------------------

animal = 'RY7';
dayepochs =   [01 01;
              03 02;
              04 01;
              04 03;
              05 01;
              05 03;
              06 01;
              06 03];


a = animaldef(animal);
animalToPath(a{2});

task=[];
cnt = 1;

%% going over epochs and days 
for i = 1:size(dayepochs,1)
    
    % dayepoch = dayepochs(i,:);    
    % dayepoch is a 1x2 of [day epoch]
    formatSpec = "%stask%02d";
    session = dayepochs(i,1);
    epoch   = dayepochs(i,2);
    taskfilename = sprintf(formatSpec,"RY7",session);
    % TIP B: taskfiles are RY7task02.mat (notice the zeros. numbers must always be 2 digit format. see doc file for sprintf() for help formatting a string.)
    % (1) make filename, for example RY7task01-02.mat ... generate this string with dayepoch variable
    % (2)  check if task filename exists in animal_direct folder, if it doesn't exist, make it
    
    % Whether to load an existing task file or make a new one
    newSession  = cnt>1 && session ~= dayepochs(cnt-1,1);
    
    if ~exist(taskfilename)
        task{session}{epoch} = struct();
        % blank slate structure
        if newSession
            task = [];
            disp(['Task structure cleared for session=' num2str(session) ' epoch=' num2str(epoch)]);
        end
    else
        % load task file
        % whenever day changes, and task file does not exist, make new
        load(taskfilename);
        disp(['Loading ' taskfilename]);
    end
    
    % (3) load proper callback structure from RY7callback.mat
    formatSpec2 = "RY7callback-%02d-%02d.mat";
    loadfilename = sprintf(formatSpec2, session, epoch);
    warning off; load(loadfilename); warning on;
    disp(['Loading ' loadfilename]);
    
    %% process valid epoches
    if ~isempty(callback{session}{epoch})
        callback_table = callback{session}{epoch}.perf.table;
        
        % CLEAR DATA in the callback table
        for row = 1:height(callback_table)
            currrow = callback{session}{epoch}.perf.table(row,:);
            
            % Mark rows with nan in trial plat and remove them in the last 
            if isnan(currrow.trialplat)
                currrow.wellstatespace = 0;
            else
                currrow.wellstatespace = 1;
            end
                
            
            % MAKE TIME RESET
            if row > 1
                prevrow = callback{session}{epoch}.perf.table(row-1,:);
                if currrow.time < prevrow.time
                    disp('')
                    currrow.time = currrow.time + prevrow.time;
                end
            end
        end
        
        
        % MAKE VARIABLES FOR TABLE, all the same size T x 1
        tableheight = height(callback_table)-1;
        trial = zeros(tableheight,1);
        block = zeros(tableheight,1);
        start = zeros(tableheight,1);
        stop = zeros(tableheight,1);
        type = strings(tableheight,1);
        reward = zeros(tableheight,1);
   
        %% Examine perf table row by row
        start(2) = 0;
        cntblock = 0;
        cnttrial = 1;
        refplat = callback_table(1,:).trialplat;
        for row = 1:height(callback_table)
            % variable for current row of table (replace all instances below
            % that share this content with this variable)
            currrow = callback{session}{epoch}.perf.table(row,:);
            % variable for previous row of table (replace all instances below
            % that share this content with this variable)
            

            if ~isnan(currrow.time)
                trial(row) = cnttrial;

                time = currrow.time;
                stop(row) = time;
                if row > 2
                    prevrow = callback{session}{epoch}.perf.table(row-1,:);
                    start(row) = prevrow.time;
                end
                
                % the block changes when the arena well changes
                if callback{session}{epoch}.const.seq.mode == "cuememory_block"
                    currplat = currrow.trialplat;
                    if (currplat ~= refplat && currplat ~= 5)
                        cntblock = cntblock + 1;
                        refplat = currplat;
                    end
                    block(row) = cntblock;
                end
                
                currtype = currrow.seq;
                if currrow.trial2 == "cue" && currtype== 1
                    type(row) = "cue";
                elseif currrow.trial2 == "memory" && currtype== 1 
                    type(row) = "memory";
                elseif currtype== 2 
                    type(row) = "home";
                end
                
                reward(row) = currrow.correct;
                cnttrial = cnttrial+1;
                
            end
        end % end of table variable creation
        
        % Remove rows with nan, 
        for row = 1:height(callback_table)
             currrow = callback{session}{epoch}.perf.table(row,:);
            if currrow.wellstatespace == 0
                currow = [];
            end
        end  
    else
        disp(['Skipping session=' num2str(session) ' epoch=' num2str(epoch)]);
    end % end examining callback
    
    % CREATE TABLE
    trialtable = table(trial, block, start, stop, type, reward); 
    assert(~isempty(trialtable), "Uh oh, trial table is empty")
    disp(['Writing callback to session= ' num2str(session) ' epoch=' num2str(epoch)]);
    disp('-------------');
    disp('');
    lastSession = find(session == dayepochs(:,1));
    lastSession = lastSession(end) == cnt;
    task{session}{epoch}.callback.trialtable = trialtable; %save the table to the task structure
    if lastSession
        save(taskfilename,'task')
    end
    
    cnt = cnt+1;   
end


