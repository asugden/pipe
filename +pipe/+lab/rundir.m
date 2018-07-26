function out = rundir(mouse, date, run, server)
%RUNDIR Get the path to a run folder, accounting for extra text after
%   the key phrases

    
    if ~isinteger(run) && ~isfloat(run), run = str2num(run); end
    
    out = [];
    mousedir = pipe.lab.datedir(mouse, date, server);
    if isempty(mousedir), return; end
    
    matchstr = sprintf('%s_%s_run%i', date, mouse, run);
    
    % Check if the base path exists
    if exist(fullfile(mousedir, matchstr), 'file') > 0
        out = fullfile(mousedir, matchstr);
        return
    end
    
    % Otherwise, search for a match
    fs = dir(mousedir);
    for i=1:length(fs)
        if fs(i).isdir
            if length(fs(i).name) > length(matchstr)
                if strcmp(fs(i).name(1:length(matchstr)), matchstr)
                    if ~isstrprop(fs(i).name(length(matchstr)+1), 'digit')
                    	out = fullfile(mousedir, fs(i).name);
                    end
                end
            end
        end
    end
end

