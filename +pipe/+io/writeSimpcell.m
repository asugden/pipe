function writeSimpcell(mouse, date, run, server, varargin)
%SAVESIMPCELL Generate simpcell options generally
%   run can be empty (all runs of the date), an int, or a vector

    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'force', false);  % If true, overwrite simpcell files
    addOptional(p, 'raw', true);  % Include the raw data
    addOptional(p, 'f0', true);  % Include the running f0 baseline
    addOptional(p, 'deconvolved', true);  % Deconvolve and include deconvolved traces if true
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    if isnumeric(date), date = num2str(date); end
    if nargin < 4, server = []; end
    if nargin < 3, run = pipe.lab.runs(mouse, date, server); end
    
    if length(run) > 1
        for r = run
            pipe.io.simpcell(mouse, date, r, server, p);
        end
    end

    %% Check if function should be run and load all essential data
    
    % Make the simpcell path and check if it exists if necessary
    spath = pipe.path(mouse, date, run, 'simpcell', server);
    if ~p.force && exist(spath), return; end
    
    % Load cellsort file
    gd = pipe.load(mouse, date, run, 'signals', p.server);
    if isempty(gd)
        error(sprintf('Signals file not found for %s %s %03i', mouse, date, run));
    end
    
    % And initalize names of variables to be saved
    savevars = {};
    
    %% Get dFF and recording values
    
    savevars = [savevars {'ncells', 'nframes', 'neuropil', 'dff', 'centroid', 'masks'}];
    if p.raw, savevars{end+1} = 'raw'; end
    if p.f0, savevars{end+1} = 'f0'; end
    
    % Load info file and get framerate
    info = pipe.metadata(sbxPath(mouse, date, run, 'sbx', 'server', p.server));
    framerate = info.framerate;
    
    % Prep the output
    ncells = length(gd.cellsort) - 1;
    nframes = length(gd.cellsort(1).timecourse.dff_axon);
    neuropil = gd.cellsort(end).timecourse.dff_axon;
    dff = zeros(ncells, nframes);
    f0 = zeros(ncells, nframes);
    raw = zeros(ncells, nframes);
    centroid = zeros(ncells, 2);
    
    if ncells > 255
        masks = zeros(info.height, info.width, 'uint16');
    else
        masks = zeros(info.height, info.width, 'uint8');
    end
    
    % Copy from cellsort
    for i = 1:ncells
        dff(i, :) = gd.cellsort(i).timecourse.dff_axon;
        f0(i, :) = gd.cellsort(i).timecourse.f0_axon;
        raw(i, :) = gd.cellsort(i).timecourse.raw;
        
        if isfield(gd.cellsort(i), 'binmask')
            mask = gd.cellsort(i).binmask;
        else
            mask = gd.cellsort(i).mask;
        end
        
        masks(mask) = i;
        
        centr = regionprops(mask);
        if ~isempty(centr)
            cx = [centr(1).Centroid(1)];
            cy = [centr(1).Centroid(2)];
            for j = 2:length(centr)
                cx = [cx centr(j).Centroid(1)];
                cy = [cy centr(j).Centroid(2)];
            end
            centroid(i, 1) = mean(cx);
            centroid(i, 2) = mean(cy);
        end

        if sum(dff(i, :)) == 0
            fprintf('WARNING: Cell %i has a dff of all zeros')
        end
        
    end
    
    %% Running, brain motion, and pupil
    
    savevars = [savevars {'running', 'brainmotion', 'pupil'}];
    
    % Load the rotary encoder running data, if possible
    running = [];
    
    quadfile = pipe.load(mouse, date, run, 'quad', p.server);
    if ~isempty(quadfile)
        running = quadfile.quad_data;
        if length(running) == 2*nframes
            running = running(1:2:length(running)) + running(2:2:length(running));
        end
    else
        quadfile = pipe.load(mouse, date, run, 'position', p.server);
        if ~isempty(quadfile)
            running = quadfile.position;
        end
    end
    
    brainmotion = pipe.proc.brainposition(mouse, date, run, server);
    
    [pupil_dx, pupil_dy, pupil_sum, pupil] = sbxPupil(mouse, date, run, server);
    
    
    %% Deconvolution
    
    if p.deconvolved
        savevars{end+1} = 'deconvolved';
        
        decon = pipe.load(mouse, date, run, 'decon');
        if isempty(decon)
            display('Deconvolving signals...')
            deconvolved = pipe.proc.deconvolve(dff);
            dpath = pipe.path(mouse, date, run, 'decon', 'estimate', true);
            save(dpath, 'deconvolved');
        else
            deconvolved = decon.deconvolved;
        end
    end
    
    %% Save
    
    save(spath, savevars{:})
end