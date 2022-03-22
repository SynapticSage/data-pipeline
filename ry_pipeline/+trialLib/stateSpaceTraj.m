function T = stateSpaceTraj(T)
% Compute the statespaces: Overall, Cue, Memory, Completion

t.ssAll  = nan(height(trajTable),1);
t.ssCue  = nan(height(trajTable),1);
t.ssMem  = nan(height(trajTable),1);
t.ssComp = nan(height(trajTable),1);
t.ssAll_day  = nan(height(trajTable),1);
t.ssCue_day  = nan(height(trajTable),1);
t.ssMem_day  = nan(height(trajTable),1);
t.ssComp_day = nan(height(trajTable),1);
t.ssAll_all  = nan(height(trajTable),1);
t.ssCue_all  = nan(height(trajTable),1);
t.ssMem_all  = nan(height(trajTable),1);
t.ssComp_all = nan(height(trajTable),1);

[groups, uDay, uEpoch] = findgroups(t.day, t.epoch);
% Get est prob corect
for g = groups'
    G = group == g;
    t=T(G,:);
    t.ssAll = getestprobcorrect(t.correct);
    filt = t.cuemem == "cue";
    t.ssCue(filt) = getestprobcorrect(t.correct(filt),1/4);
    filt = t.cuemem == "mem";
    t.ssMem(filt) = getestprobcorrect(t.correct(filt),1/4);
    filt = t.cuemem == "mem";
    completions = getCompletions(t);
    t.ssComp = getestprobcorrect(completions, (1/4) ^ 4);

    T(G,:) = t;
end

[groups, uDay] = findgroups(t.day);
% Get est prob corect
for g = groups'
    G = group == g;
    t=T(G,:);
    t.ssAll_day = getestprobcorrect(t.correct);
    filt = t.cuemem == "cue";
    t.ssCue_day(filt) = getestprobcorrect(t.correct(filt),1/4);
    filt = t.cuemem == "mem";
    t.ssMem_day(filt) = getestprobcorrect(t.correct(filt),1/4);
    filt = t.cuemem == "mem";
    completions = getCompletions(t);
    t.ssComp_day = getestprobcorrect(completions, (1/4) ^ 4);
    T(G,:) = t;
end

T.ssAll_all = getestprobcorrect(T.correct);
filt = T.cuemem == "cue";
T.ssCue_all(filt) = getestprobcorrect(T.correct(filt),1/4);
filt = T.cuemem == "mem";
T.ssMem_all(filt) = getestprobcorrect(T.correct(filt),1/4);
filt = T.cuemem == "mem";
completions = getCompletions(T);
T.ssComp_all = getestprobcorrect(completions, (1/4) ^ 4);

function completions  = getCompletions(t)

    uBlock  = unique(t.block);
    completions = zeros(numel(uBlock),1);
    for b = uBlock
        block = t(t.block == b,:);
        if ismember(8,t.traj) && t(t.traj==8,:).correct
            completion = 1;
        else 
            completion = 0;
        end
    end
