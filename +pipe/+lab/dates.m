function out = dates(mouse, server)
%SBXDATES List all dates of recordings for mouse mouse

    if nargin < 2, server = []; end

    mousedir = pipe.lab.mousedir(mouse, server);
    pattern = ['^\d{6}_' mouse '.*'];
    
    out = [];
    
    fs = dir(mousedir);
    for i=1:length(fs)
        if fs(i).isdir
            if regexp(fs(i).name, pattern)
                date = str2num(fs(i).name(1:6));
                if ~isempty(pipe.lab.runs(mouse, date, server))
                    out(length(out)+1) = date;
                end
            end
        end
    end
    
    out = sort(out);
end

