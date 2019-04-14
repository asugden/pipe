function out = runs(mouse, date, server)
%SBXRUNS List all runs in a folder

    % If date is an integer, convert to string
    if ~ischar(date), date = num2str(date); end
    if nargin < 3, server = []; end
    
    % Initialize the base directory and scan directory
    % Get the base directory from sbxDir.
    
    out = [];
    searchdir = pipe.lab.datedir(mouse, date, server);
    if isempty(searchdir), disp('ERROR: Directory not found'); return; end
    matchstr = sprintf('%s_%s_', date, mouse);
    
    % Search for all directory titles that match a run
    fs = dir(searchdir);
    for i=1:length(fs)
        if fs(i).isdir
            if length(fs(i).name) > length(matchstr) && ...
                    strcmp(fs(i).name(1:length(matchstr)), matchstr)
                runnum = [];
                j = length(matchstr) + 1;
                if length(fs(i).name) >= j + 2 && ...
                        strcmp(fs(i).name(j:j+2), 'run')
                    j = j + 3;
                end
                while j <= length(fs(i).name) && ...
                        isstrprop(fs(i).name(j), 'digit')
                    runnum = [runnum fs(i).name(j)]; %#ok<AGROW>
                    j = j + 1;
                end
                if ~isempty(runnum)
                    out = [out str2double(runnum)]; %#ok<AGROW>
                end
            end
        end
    end
    out = sort(out);
end

