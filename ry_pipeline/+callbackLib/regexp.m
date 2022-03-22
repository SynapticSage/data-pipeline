function R = regexp(name)
% REGULAR_EXPRESSION parse regular expression for animal session epoch

pattern = '(.*_)*(\()?(?<animal>\w*)_(?<session>\w*)_(?<epoch>\w*)(\))?(?<descriptor>_\w*)(\))?(?<ext>\..*)?';
R = regexp(name, pattern, 'names');
