function out = rundir(mouse, date, run, server)
%RUNDIR Get the path to a run folder, accounting for extra text after
%   the key phrases

%   Expects pathbase\mousedir\datedir\rundir\files defined in their
%   respective functions
%   mousedir expected to be just the mouse name
%   datedir expected to be [date string]_mouse or [date string]
%   rundir expected to be [date string]_[mouse]_run[run int] or 
%       [date_string]_[mouse]_[3-digit run int]
%   Examples:
%       pathbase\CB173\160519_CB173\160519_CB173_run8\
%       pathbase\CB173\160519\160519_CB173_008\
    
    if ~isinteger(run) && ~isfloat(run), run = str2num(run); end
    
    out = [];
    mousedir = pipe.lab.datedir(mouse, date, server);
    if isempty(mousedir), return; end
    
    matchstr1 = sprintf('%s_%s_run%i', date, mouse, run);
    matchstr2 = sprintf('%s_%s_%03i', date, mouse, run);
    
    % Check if the base path exists
    if exist(fullfile(mousedir, matchstr1), 'file') > 0
        out = fullfile(mousedir, matchstr1);
        return
    elseif exist(fullfile(mousedir, matchstr2), 'file') > 0
        out = fullfile(mousedir, matchstr2);
        return
    end
    
    % Otherwise, search for a match
    fs = dir(mousedir);
    for i=1:length(fs)
        if fs(i).isdir
            if length(fs(i).name) > length(matchstr1)
                if strcmp(fs(i).name(1:length(matchstr1)), matchstr1)
                    if ~isstrprop(fs(i).name(length(matchstr1)+1), 'digit')
                    	out = fullfile(mousedir, fs(i).name);
                        return
                    end
                end
                if strcmp(fs(i).name(1:length(matchstr2)), matchstr2)
                    if ~isstrprop(fs(i).name(length(matchstr2)+1), 'digit')
                    	out = fullfile(mousedir, fs(i).name);
                        return
                    end
                end
            end
        end
    end
end

