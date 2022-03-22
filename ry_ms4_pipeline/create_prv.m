function outStr = create_prv(srcFile,destFile,args)
    % create_prv(srcFile,destFile,args) will run ml-prv-create in the base
    % conda environment 
    % options:
    %   --stat  : do not write output file. write prv record to console
    %   --sha1  : do not write output file. write file checksum to console
    %   --help
    if ~exist('args','var')
        args = '';
    end
    conda_path = get_conda_path();
    conda_env  = get_conda_env();
    runStr = sprintf('. %s && conda activate %s && ml-prv-create %s %s %s',...
        conda_path,conda_env, srcFile,destFile,args);runStr = sprintf('. %s && conda activate %s && ml-prv-create %s %s %s',...
        conda_path,conda_env, srcFile,destFile,args);
    [out,outStr] = system(runStr,'-echo');
