function out = load(mouse, date, run, ftype, server, varargin)
% LOAD loads any type of important file of the scanbox format. Uses path
% Can be passed a single input, the path to a file, which it will attempt
% to parse

    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'error', true);       % Raise error if the file doesn't exist if true
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    % Set the default values for mouse, date, and run
    if isnumeric(date), date = num2str(date); end
    if nargin < 3, run = pipe.lab.runs(mouse, date, p.server); end
    
    % Iterate over every run
    if length(run) > 1
        for r = run
            pipe.io.simpcell(mouse, date, r, p);
        end
    end

    path = [];
    out = [];
    
    if nargin == 1
        path = mouse;
        [~, ~, ftype] = fileparts(path);
    end
    if nargin < 5, server = []; end
    
    if isempty(path), path = pipe.lab.datapath(mouse, date, run, ftype, server); end
    if isempty(path)
        if p.error
            error('File not found');
        else
            return;
        end
    end
    
    % Read the necessary filetypes differently
    switch ftype
        case 'bhv'
            out = pipe.io.read_bhv(path);
        case 'ephys'
            out = pipe.io.read_sbxephys(mouse, date, run, server);
        case 'info'
            out = pipe.metadata(path);
        case 'onsets'
            out = pipe.io.trial_times(mouse, date, run, server);
        case 'tif'
            out = pipe.io.read_tiff(path);
        case 'trials'
            out = pipe.io.trial_times(mouse, date, run, server);
        otherwise
            if ~exist(path, 'file')
                error('File not found');
            else
                out = builtin('load', path, '-mat');
            end
    end
end