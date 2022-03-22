function out = get_conda_env()
% Returns the path to conda.sh, env should be stored in conda_env.txt in
% your matlab path
out = fileread('conda_env.txt');
out = strtrim(out);
