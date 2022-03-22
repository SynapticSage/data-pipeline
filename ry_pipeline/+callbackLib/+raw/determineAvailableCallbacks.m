function [filenames, filetable] = determineAvailableCallbacks(folder)


files = dir([folder filesep 'callback_*.mat']);
for file = files(:)'
    R = regular_expression(file.name)
end

function R = regular_expression(name)
% REGULAR_EXPRESSION parse regular expression for animal session epoch

    pattern = '(.*_)*(\()?(?<animal>\w*)_(?<session>\w*)_(?<epoch>\w*)(\))?(?<descriptor>_\w*)(\))?(?<ext>\..*)?';
    R = regexp(name, pattern, 'names');

