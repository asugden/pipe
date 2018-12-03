function clean(mouse, dates, server)
%PIPE.LAB.CLEAN Remove unnecessary processing files such as .sbxreg from a
%   mouse and optional date.

    if nargin < 3, server = []; end
    if nargin < 2 || isempty(dates), dates = pipe.lab.dates(mouse, server); end

    for date = dates
        runs = pipe.lab.runs(mouse, date, server);
        for run = runs
            path = pipe.path(mouse, date, run, 'sbxreg', server);
            if ~isempty(path)
                disp(path);
                delete(path);
            end
        end
    end
end

