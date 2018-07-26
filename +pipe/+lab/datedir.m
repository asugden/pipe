function out = datedir(mouse, date, server)
%DATEDIR Gets the directory of the mouse and date, accounting for 
%   the fact that you may have added extra text

    if nargin < 3, server = []; end
    
    out = [];
    
    mousedir = pipe.lab.mousedir(mouse, server);
    if isempty(mousedir), return; end
        
    matchstr = sprintf('%s_%s', date, mouse);

    if exist(fullfile(mousedir, matchstr), 'file') > 0
        out = fullfile(mousedir, matchstr);
        return
    end
    
    fs = dir(mousedir);
    for i=1:length(fs)
        if fs(i).isdir
            if length(fs(i).name) > length(matchstr)
                if strcmp(fs(i).name(1:length(matchstr)), matchstr)
                    out = fullfile(mousedir, fs(i).name);
                end
            end
        end
    end
end

