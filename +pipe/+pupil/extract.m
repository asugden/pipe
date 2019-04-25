function [dx, dy, psum, area, quality] = extract(mouse, date, run, varargin)
% lowpass, force, draw)
%UNTITLED11 Summary of this function goes here
%   Detailed explanation goes here

    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'server', []);         % Server name, if not this server
    addOptional(p, 'force', false);       % Force overwriting
    addOptional(p, 'emission', true);     % If false, invert image
    addOptional(p, 'lowpass', true);      % Lowpass filter the result
    addOptional(p, 'draw', false);        % Draw images for testing
    addOptional(p, 'interactive', false); % Allow fixing of missing parameters
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;

    % Considerable fluctuations on the order of 2s. Make sure to remove.

    %% Prepare the output and check if existing
    
    version = 2.0;
    dx = [];
    dy = [];
    psum = [];
    area = [];
    quality = [];
    
    % Load file if possible
    save_path = pipe.path(mouse, date, run, 'pdiam', p.server);
    if ~isempty(save_path) && ~p.force
        out = load(save_path, '-mat');
        if isfield(out, 'version') && out.version >= 2
            dx = out.dx;
            dy = out.dx;
            psum = out.psum;
            area = out.area;
            quality = out.quality;
            return;
        end
    end
    
    %% Check data quality
    
    % If there is no pmask file, then nothing can be done. Abort.
    pmaskpath = pipe.path(mouse, date, run, 'pmask', p.server);
    if ~exist(pmaskpath)
        error('No mask file created. Run pipe.pupil.masks before pipe.pupil.extract.');
    end
    
    pmask = load(pmaskpath, '-mat');
    if ~isfield(pmask, 'cx') || ~isfield(pmask, 'bwmask') || ~isfield(pmask, 'version') || pmask.version < 2
        error('No cx value in pmask. Rerun pipe.pupil.masks.');
    end
    
    % Load the pupil movie file if possible
    pupil_path = pipe.path(mouse, date, run, 'pupil', p.server);
    if isempty(pupil_path)
        error('No eye file found');
    end
    e = load(pupil_path, '-mat');
    if ~isfield(e, 'data') 
        error('No pupil data in eye file.');
    end
    
    %% Extract the pupil intensity, position, and size
    
    info = pipe.metadata(pipe.path(mouse, date, run, 'sbx', p.server));
    psum = pipe.pupil.sum_intensities(e.data, pmask.bwmask, info.framerate, p.lowpass);
    
    %try
    [dx, dy, area, radii, quality] = pipe.pupil.position(squeeze(e.data), ...
        pmask.bwmask, pmask.cx, pmask.cy, 'draw', p.draw, ...
        'emission', p.emission, 'interactive', p.interactive);
    %catch
    %    error('pipe.pupil.position failed, check mask, center, and single frame quality ...')
    %end
    
    if length(psum) > info.nframes, psum = psum(1:info.nframes); end
    if length(dx) > info.nframes, dx = dx(1:info.nframes); end
    if length(dy) > info.nframes, dy = dy(1:info.nframes); end
    if length(area) > info.nframes, area = area(1:info.nframes); end
    
    if ~p.emission
        mx = max(psum);
        mn = min(psum);
        psum = mx - (psum - mn);
    end
    
    sleep_mask = pmask.sleep_mask;
    save(save_path, 'psum', 'area', 'dx', 'dy', 'quality', ...
         'radii', 'version', 'sleep_mask');
end
