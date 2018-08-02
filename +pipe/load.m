function out = load(mouse, date, run, ftype, server)
% LOAD loads any type of important file of the scanbox format. Uses path
% Can be passed a single input, the path to a file, which it will attempt
% to parse

    path = [];
    out = [];
    
    if nargin == 1
        path = mouse;
        [~, ~, ftype] = fileparts(path);
    end
    if nargin < 5, server = []; end
    
    if isempty(path), path = pipe.lab.datapath(mouse, date, run, ftype, server); end
    if isempty(path), error('File not found'); end
    
    % Read the necessary filetypes differently
    switch ftype
        case 'bhv'
            out = pipe.io.readBhv(path);
        case 'ephys'
            out = pipe.io.sbxEphys(mouse, date, run, server);
        case 'info'
            out = pipe.info(path);
        case 'onsets'
            out = pipe.io.sbxOnsets(mouse, date, run, server);
        case 'tif'
            out = pipe.io.readTiff(path);
        otherwise
            if ~exist(path, 'file')
                error('File not found');
            else
                out = load(path, '-mat');
            end
    end
end