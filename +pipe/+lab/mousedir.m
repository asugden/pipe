function out = mousedir(mouse, server)
%MOUSEDIR Gets the directory of the mouse.
%   Accounts for extra layer of folders between scanbase and mousedir.
    if nargin < 2, server = []; end

    scanbase = pipe.lab.pathbase(server);
    
    % Prepare the output
    out = [];
    
    % Get the mouse directory
    mousedir = fullfile(scanbase, mouse);
    if exist(mousedir, 'file')
        out = mousedir;
        return
    end
    
    % Allows for an extra folder layer after scanbase.
    % Could work for any server.
    if strcmpi(server, 'anastasia')
        fs = dir(scanbase);
        for i=1:length(fs)
            test_dir = fullfile(scanbase, fs(i).name, mouse);
            if fs(i).isdir && exist(test_dir, 'file')
                out = test_dir;
                return
            end
        end
    end

end

