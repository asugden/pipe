function out = mousedir(mouse, server)
%MOUSEDIR Gets the directory of the mouse.
%   Accounts for extra layer of folders between scanbase and mousedir.

%   Expects pathbase\mousedir\datedir\rundir\files defined in their
%   respective functions
%   mousedir expected to be just the mouse name
%   datedir expected to be [date string]_mouse or [date string]
%   rundir expected to be [date string]_[mouse]_run[run int] or 
%       [date_string]_[mouse]_[3-digit run int]
%   Examples:
%       pathbase\CB173\160519_CB173\160519_CB173_run8\
%       pathbase\CB173\160519\160519_CB173_008\

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
    if strcmpi(server, 'anastasia') || strcmpi(server, 'nasquatch')
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

