function answers = isNewOrganization(dayFolders)

if iscellstr(dayFolders) || ischar(dayFolders)
    dayFolders = string(dayFolders);
end

dcount = 0;
answers = false(numel(dayFolders),1);
for dayFolder = dayFolders
    dcount = dcount + 1;
    recs_in_dayFolder        = dir(fullfile(dayFolder, '*.rec'));
    recs_in_dayFolder_subdir = dir(fullfile(dayFolder, '**/*.rec'));
    if numel(recs_in_dayFolder) == 0 && numel(recs_in_dayFolder_subdir) > 0
        answers(dcount) = true;
    end
end

