function out = load(mouse, date, run, ftype, server)
% LOAD loads any type of important file of the scanbox format. Uses path

    if nargin < 4
        error('Call with mouse, date, run, and type of file.');
    elseif nargin < 5
        server = [];
    end
    
    out = [];
    path = pipe.lab.datapath(mouse, date, run, ftype, server);
    
    % Share the results
    if isempty(path)
        error('File not found');
    end
    
    % Read the necessary filetypes differently
    switch ftype
        case 'bhv'
            out = pipe.io.bhvRead(path);
        case 'ephys'
            out = pipe.io.sbxEphys(mouse, date, run, server);
        case 'info'
            out = pipe.info(path);
        case 'onsets'
            out = pipe.io.sbxOnsets(mouse, date, run, server);
        otherwise
            if ~exist(path, 'file')
                error('File not found');
            else
                out = load(path, '-mat');
            end
    end
end