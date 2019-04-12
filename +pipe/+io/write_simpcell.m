function write_simpcell(mouse, date, run, varargin)
%SIMPCELL Generate simpcell file, which contains all possible data
%   run can be empty (all runs of the date), an int, or a vector

    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'server', []);         % Server name, empty if the same server
    addOptional(p, 'force', false);       % If true, overwrite simpcell files
    addOptional(p, 'raw', true);          % Include the raw data
    addOptional(p, 'f0', true);           % Include the running f0 baseline
    addOptional(p, 'deconvolved', true);  % Deconvolve and include deconvolved traces if true
    addOptional(p, 'pupil', false);       % Add pupil data-- turned off until improvements are made
    addOptional(p, 'brain_forces', false);% Add the motion of the brain as forces
    addOptional(p, 'photometry', false);  % Add photometry data
    addOptional(p, 'photometry_fiber', 1);% Which photometry fiber(s) to include, can be array
    addOptional(p, 'tags', {});           % Add single-word tags such as 'naive', 'hungry', 'sated'
    addOptional(p, 'training', false);    % Guess if a training run. If set to true, 
                                          % it will throw an error if not a training run.
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    % Set the default values for mouse, date, and run
    if isnumeric(date), date = num2str(date); end
    if nargin < 3, run = pipe.lab.runs(mouse, date, p.server); end
    
    % Iterate over every run
    if length(run) > 1
        for r = run
            pipe.io.write_simpcell(mouse, date, r, p);
        end
    end
    
    %% The version number to be saved
    
    version = 2.0;

    %% Check if function should be run and load all essential data
    
    % Make the simpcell path and check if it exists if necessary
    spath = pipe.path(mouse, date, run, 'simpcell', p.server, 'estimate', true);
    if ~p.force && exist(spath), return; end
    
    % Load cellsort file
    gd = pipe.load(mouse, date, run, 'signals', p.server, 'error', false);
    if isempty(gd)
        error(sprintf('Signals file not found for %s %s %03i', mouse, date, run));
    end
    
    % And initalize names of variables to be saved
    preprocess_pars = struct('unknown', true);
    postprocess_pars = struct('unknown', true);
    
    if isfield(gd, 'preprocess_pars'), preprocess_pars = gd.preprocess_pars; end
    if isfield(gd, 'postprocess_pars'), postprocess_pars = gd.postprocess_pars; end
    
    savevars = {'version', 'preprocess_pars', 'postprocess_pars'};
    if ~isempty(p.tags)
        tags = p.tags;
        savevars{end+1} = 'tags';
    end
    
    %% Get dFF and recording values
    
    savevars = [savevars {'framerate', 'ncells', 'nframes', 'neuropil',...
                          'dff', 'centroid', 'masks', 'weighted_masks'}];
    if p.raw, savevars{end+1} = 'raw'; end
    if p.f0, savevars{end+1} = 'f0'; end
    
    % Load info file and get framerate
    info = pipe.metadata(pipe.path(mouse, date, run, 'sbx', p.server));
    framerate = single(info.framerate);
    
    % Prep the output
    ncells = int16(length(gd.cellsort) - 1);
    nframes = int32(length(gd.cellsort(1).timecourse.dff_axon));
    neuropil = single(gd.cellsort(end).timecourse.dff_axon);
    dff = zeros(ncells, nframes, 'single');
    f0 = zeros(ncells, nframes, 'single');
    raw = zeros(ncells, nframes, 'single');
    centroid = zeros(ncells, 2, 'single');
    
    weighted_masks = zeros(info.height, info.width, 'single');
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
            wmask = gd.cellsort(i).mask;
        else
            mask = gd.cellsort(i).mask;
            wmask = gd.cellsort(i).weights;
        end
        
        masks(mask') = i;
        weighted_masks(mask') = wmask(mask)';
        
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
    
    savevars = [savevars {'running', 'brainmotion'}];
    
    % Load the rotary encoder running data, if possible
    running = [];
    
    quadfile = pipe.load(mouse, date, run, 'quad', p.server, 'error', false);
    if ~isempty(quadfile)
        running = quadfile.quad_data;
        if length(running) == 2*nframes
            running = running(1:2:length(running)) + running(2:2:length(running));
        end
    else
        quadfile = pipe.load(mouse, date, run, 'position', p.server, 'error', false);
        if ~isempty(quadfile)
            running = quadfile.position;
        end
    end
    
    brainmotion = single(pipe.proc.brainposition(mouse, date, run, p.server));
    
    if p.pupil
        savevars = [savevars, 'pupil'];
        [pupil_dx, pupil_dy, pupil_sum, pupil] = sbxPupil(mouse, date, run, p.server);
    end
    
    
     %% Brain motion
    
    if p.brain_forces
        savevars = [savevars {'scaleml', 'scaleap', 'shearml', 'shearap', 'transml', 'transap'}];
        mot = pipe.proc.brain_forces(mouse, date, run, p.server);
        shearml = mot.shearml;
        shearap = mot.shearap;
        transml = mot.transml;
        transap = mot.transap;
        scaleml = mot.scaleml;
        scaleap = mot.scaleap;
    end
    
    
    %% Deconvolution
    
    if p.deconvolved
        savevars{end+1} = 'deconvolved';
        
        decon_path = pipe.path(mouse, date, run, 'decon', p.server);
        if isempty(decon_path)
            display('Deconvolving signals...')
            deconvolved = pipe.proc.deconvolve(dff);
            dpath = pipe.path(mouse, date, run, 'decon', p.server, 'estimate', true);
            save(dpath, 'deconvolved');
        else
            decon = load(decon_path, '-mat');
            deconvolved = single(decon.deconvolved);
        end
    end
    
    %% Behavioral data
    
    ons = pipe.io.trial_times(mouse, date, run, p.server);
    
    if p.training && (isempty(ons) || ~isfield(ons, 'onsets'))
        error('Behavioral data from Monkeylogic not found.');
    end
    
    if ~isempty(ons) && isfield(ons, 'onsets')
        savevars = [savevars {'onsets', 'offsets', 'licking', 'ensure', 'quinine', 'condition', 'trialerror', 'codes', 'orientations'}];
        
        onsets = ons.onsets;
        offsets = ons.offsets;
        licking = ons.licking;
        ensure = ons.ensure;
        quinine = ons.quinine;
        condition = ons.condition;
        trialerror = ons.trialerror;
        codes = ons.codes;
        orientations = ons.orientation;
    elseif ~isempty(ons)
        savevars = [savevars {'licking'}];
        
        licking = ons.licking;
    end
    
    %% Photometry
    
    if p.photometry
        savevars = [savevars {'photometry_dff', 'photometry_raw'}];
        
        ephys = pipe.io.read_sbxephys(mouse, date, run, p.server);
        
        if p.photometry_fiber == 1
            photometry_dff = localMatchPhotometry2P(ephys.frames2p, ephys.photometry1, ephys.Fs, nframes, true);
            photometry_raw = localMatchPhotometry2P(ephys.frames2p, ephys.photometry1, ephys.Fs, nframes, false);
        elseif p.photometry_fiber == 2
            photometry_dff = localMatchPhotometry2P(ephys.frames2p, ephys.photometry2, ephys.Fs, nframes, true);
            photometry_raw = localMatchPhotometry2P(ephys.frames2p, ephys.photometry2, ephys.Fs, nframes, false);
        elseif length(p.photometry_fiber) == 2
            photometry_dff = zeros(2, nframes);
            photometry_raw = zeros(2, nframes);
            
            photometry_dff(1, :) = localMatchPhotometry2P(ephys.frames2p, ephys.photometry1, ephys.Fs, nframes, true);
            photometry_raw(1, :) = localMatchPhotometry2P(ephys.frames2p, ephys.photometry1, ephys.Fs, nframes, false);
            
            photometry_dff(2, :) = localMatchPhotometry2P(ephys.frames2p, ephys.photometry2, ephys.Fs, nframes, true);
            photometry_raw(2, :) = localMatchPhotometry2P(ephys.frames2p, ephys.photometry2, ephys.Fs, nframes, false);
        else
            error('Photometry fibers < 1 or > 2 are not implemented.');
        end 
    end
    
    %% Save
    
    save(spath, savevars{:})
end


function out = localMatchPhotometry2P(frames, photometry, sampling_rate, nframes, axondff)
%MATCHPHOTOMETRYTO2P Extract the photometry trace, downsample, and match to
%   the onsets of 2p frames

    % Find the onsets if 2-photon frames
    onsets = find(diff(frames > 2.5) == 1);
    donsets = diff(onsets);
    sampling_2p = sampling_rate/mean(donsets);
    
    % Subset the photometry window
    photometry = reshape(photometry, 1, length(photometry));
    photometry = photometry(onsets(1):onsets(end) + median(donsets));
    photometry(1) = photometry(2);
    
    % Get the appropriate sampling rate correction
    tol = 0.0000001;
    [num, den] = rat(sampling_2p/sampling_rate, tol);
    while num*den < 2^31 && tol > 1e-31
        tol = tol/10;
        [num, den] = rat(sampling_2p/sampling_rate, tol);
    end
    [num, den] = rat(sampling_2p/sampling_rate, tol*10);
    
    % And resample
    out = resample(photometry, num, den);
    if axondff
        out = percentiledff(out, sampling_2p);
    end
    
    % Cut down the frames to the correct size
    if nframes > length(out)
        tempphot = zeros(1, nframes);
        tempphot(1:length(out)) = out;
        out = tempphot;
    end
    out = out(1:nframes);
    dphotlen = nframes - length(out);
    if dphotlen > 0
        appendarr = ones(1, dphotlen)*out(end);
        out = [out appendarr];
    end
end