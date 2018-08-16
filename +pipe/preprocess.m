function preprocess(mouse, date, varargin)
%PREPROCESS A pipeline function to:
%   1. Align multiple runs to the first chunk of a single run
%   2. PCA Clean, optionally
%   3. Save aligned SBX
%   4. Load in a movie of all of runs and segment using either PCA/ICA or
%       nonnegative matrix factorization
%   5. Save the output for cell-clicking via the online cell clicker
%   6. Save reference TIFFs

    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'sbxpaths', []);  % If set to a cell array of paths, mouse and date will be ignored
    addOptional(p, 'target', []);  % Target run to align to, default runs(1)
    addOptional(p, 'job', false);  % Set to true if run as a batch, blocks user interaction
    addOptional(p, 'server', []);  % Add in the server name as a string
    % addOptional(p, 'pupil', false);  % Extract pupil diameter if possible
    addOptional(p, 'runs', []);  % Defaults to all runs in the directory
    addOptional(p, 'force', false);  % Overwrite files if they exist
    addOptional(p, 'pmt', 1, @isnumeric);  % Which PMT to use for analysis, 1-green, 2-red
    addOptionla(p, 'optotune_level', []);  % Which optotune level
    addOptional(p, 'axons', false);  % Whether or not to preprocess as axons rather than cells
    addOptional(p, 'aligntype', 'affine');  % Can be set to 'affine' or 'translation'
    addOptional(p, 'extraction', 'pcaica');  % or 'nmf', or 'none', Whether to use constrained non-negative matrix factorization or PCA/ICA
    addOptional(p, 'testimages', true);  % Whether to use generate alignment and stimulus test images
    % addOptional(p, 'pcaclean', false);  % Whether or not to PCA clean
    addOptional(p, 'objective', 'nikon16x');  % The objective used (from which we can calculate cellhalfwidth)
    addOptional(p, 'sbxreg', true);  % Save registered sbx file to speed up analyses
    
    % addOptional(p, 'detect_from_pcaclean', true);  % If PCA cleaning, extract ROIs from the PCA cleaned movie
    addOptional(p, 'chunksize', 1000, @isnumeric);  % The number of frames per parallel chunk
    addOptional(p, 'downsample_t', 5, @isnumeric);  % The number of frames to downsample for ROI detection
                                                    % WARNING: Will automatically be doubled for bidirectional data 
    addOptional(p, 'downsample_xy', [], @isnumeric);  % The maximum cross-correlation to allow between overlapping ROIs, combined with overlap, default 2
    addOptional(p, 'edges', []);  % The edges of the image to be removed before ROI extraction. Will be set to sbxRemoveEdges if empty

    % ---------------------------------------------------------------------
    % Specific variables
    % PCA Cleaning
    addOptional(p, 'pcaclean_pcs', 2000);  % Number of principal components to use for PCA cleaning
    addOptional(p, 'pcabinxy', 2);  % Bin in x and y before running PCA cleaning, correcting for it afterwards
    addOptional(p, 'pcainterlace', 2);  % How much to interlace for PCA cleaning
    
    % PCA/ICA ROI Extraction
    addOptional(p, 'npcs', 1000, @isnumeric);  % The number of principal components to keep
                                               % WARNING: Divided by 4 for axons
    addOptional(p, 'firstpctokeep', 4, @isnumeric);
    addOptional(p, 'temporal_weight', 0.1, @isnumeric);  % The temporal (versus spatial) weight for PCA. Default from Schnitzer was 0.5
    addOptional(p, 'smoothing_width', 2, @isnumeric);  % Standard deviation of Gaussian smoothing kernel (pixels)
                                                       % WARNING: Divided by 2 for axons
    addOptional(p, 'spatial_threshold_sd', 2, @isnumeric);  % Threshold for the spatial filters in standard deviations. Default from Schnitzer was 5
    
    % NMF ROI Extraction
    addOptional(p, 'cellhalfwidth', [], @isnumeric);  % The half-width of a cell, default 2.5
    addOptional(p, 'mergethreshold', 0.8, @isnumeric);  % The threshold above which to merge neighboring ROIs
    addOptional(p, 'patchsize', [], @isnumeric);  % The size of a patch for NMF, can be calculated from cellhalfwidth
    addOptional(p, 'ncomponents', 40, @isnumeric);  % The number of cells to find in a patch. For advanced users only, otherwise leave unset
    
    % General ROI Extraction
    addOptional(p, 'minarea', [], @isnumeric);  % The minimum area of a cell to accept for NMF, default 7
    addOptional(p, 'maxarea', [], @isnumeric);  % The maximum area of a cell to accept for NMF, default 500
    addOptional(p, 'overlap', 0.9, @isnumeric);  % The maximum overlap to allow, combined with crosscorr
    addOptional(p, 'crosscorr', 0.9, @isnumeric);  % The maximum cross-correlation to allow between overlapping ROIs, combined with overlap
        
    % Alignment
    addOptional(p, 'refsize', 500, @isnumeric);  % Set the number of frames from which we make the reference
    addOptional(p, 'refoffset', 500, @isnumeric);  % The offset in frames for the reference image, accounts for weirdness in the first few frames
    addOptional(p, 'refstationary', false);  % Use period of immobility equal to refsize for making target
    addOptional(p, 'pre_register', false, @isboolean);  % If true and affine aligning, register with dft prior to affine aligning
    addOptional(p, 'align_tbin_s', 1, @isnumeric);  % How many seconds to bin in time for affine alignment only (DFT is every frame)
    addOptional(p, 'align_highpass_sigma', 5, @isnumeric);  % Size of the Gaussian blur to be subtracted from a downsampled image
    addOptional(p, 'align_target_rounds', 3, @isnumeric);  % Number of times to dft align the registration targets
    addOptional(p, 'align_interpolation_type', 'spline');  % If affine and binning in time, interpolate using type 'spline' or 'linear'
    
    % Overwrite other parameters specifically for alignment
    addOptional(p, 'align_edges', []);  % The edges of the image to be removed before alignment. Will be set to p.edges if empty
    addOptional(p, 'align_pmt', [], @isnumeric);  % Which PMT to use for registration, 1-green, 2-red
    addOptional(p, 'align_downsample_xy', [], @isnumeric);  % Pixels to downsample in xy, will be set to downsample_xy if empty
    % addOptional(p, 'align_from_pcaclean', false);  %

    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;

    %% Clean up inputs based on data about the file and force into a list 
    %  of .sbx files (so that this function can easily be duplicated for
    %  paths only
    
    if ~isempty(p.sbxpaths)
        sbxpaths = p.sbxpaths;
        runs = [];
        p.has_mousedate = false;
    else
        if isempty(p.runs), p.runs = pipe.lab.runs(mouse, date, p.server); end
        runs = p.runs;

        sbxpaths = {};
        for r = 1:length(runs)
            sbxpaths{end+1} = pipe.path(mouse, date, runs(r), 'sbx', 'server', p.server);
        end
        p.has_mousedate = true;
    end
    
    if isempty(sbxpaths), return; end
    
    %% Clean up the rest of the inputs
    
    info = pipe.metadata(sbxpaths{1});

    % Set the target and account for overwriting
    if isempty(p.target), p.target = sbxpaths{1}; end
    if isempty(p.edges), p.edges = pipe.lab.badedges(sbxpaths{1}); end
    if isempty(p.align_pmt), p.align_pmt = p.pmt; end
    if isempty(p.align_edges), p.align_edges = p.edges; end
    if isempty(p.align_downsample_xy), p.align_downsample_xy = p.downsample_xy; end    
    
    % Set the correct sizes based on the objective being used
    if ~isempty(p.objective)
        if isfield(info.config, 'magnification_list')
            zoom = str2num(info.config.magnification_list(info.config.magnification));
        else
            zoom = info.config.magnification;
        end
        [chw, mina, maxa, dxy] = pipe.lab.cellsize(p.objective, zoom, p.cellhalfwidth);
        if isempty(p.cellhalfwidth), p.cellhalfwidth = chw; end
        if isempty(p.minarea), p.minarea = mina; end
        if isempty(p.maxarea), p.maxarea = maxa; end
        if isempty(p.downsample_xy), p.downsample_xy = dxy; end
    end
    
    % Set the correct chunk size and downsampling based on framerate
    if info.framerate > 20, p.downsample_t = p.downsample_t*2; end
    chunksize = ceil(p.chunksize/p.downsample_t)*p.downsample_t;
        
    if ~p.has_mousedate
        if p.refstationary
            disp('WARNING: Cannot find stationarity without mouse, date, run');
            p.refstationary = false;
        end
        if p.testimages
            disp('WARNING: Cannot find stimulus onset times without mouse, date, run');
            p.testimages = false;
        end
    end 
    
    %% Align
    
    % if p.nomovetarget  % Use period of immobility to make target
    %     [p.refoffset, p.refsize] = sbxNoMoveTarget(mouse, date, p.target, p.refsize);
    % end
    
    pipe.align(sbxpaths, 'force', p.force, 'optotune_level', p.optotune_level, ...
        'edges', p.align_edges, 'pmt', p.align_pmt, 'target', p.target, ...
        'refsize', p.refsize, 'refoffset', p.refoffset, 'target_rounds', p.align_target_rounds, ...
        'tbin', p.align_tbin_s, 'binxy', p.align_downsample_xy, ...
        'highpass_sigma', p.align_highpass_sigma, 'pre_register', p.pre_register, ...
        'interpolation_type', p.align_interpolation_type);

    %% Align from pcacleaned
    
%     if p.align_from_pcaclean
%         pcapaths = {};
%         for r = 1:length(runs)
%             pcapaths{end+1} = sbxPath(mouse, date, runs(r), 'sbxclean', 'server', p.server);
%         end 
%         if ~isempty(pcapaths{1})
%             % Align
%         end
%     end

    %% Save alignment of all runs
    
    if p.sbxreg
        for r = 1:length(sbxpaths)
            path = sbxpaths{r};
            pipe.reg.save(sbxpaths{r}, 'force', p.force, 'chunksize', p.chunksize);
        end        
    end    
 
        
%         if p.pcaclean
%             sbxPCAClean(runpath, pcapath, 'npcs', p.pcaclean_pcs, 'edges', p.edges, ...
%                 'pmt', p.pmt, 'interlace', p.pcainterlace, 'binxy', p.pcabinxy, 'chunksize', chunksize);
%         end
%         
%         if p.extract_from_pcaclean && exist(pcapath)
%             runpath = pcapath;
%         end
        
       
    
    %% Extract ROIs
    
    if ~strcmpi(p.extraction, 'none') 
        savepath = sprintf('%s.ica', path(1:end-4));
            
        icaguidata = sbxExtractROIs(movpaths, savepath, p.edges, 'type', p.extraction, 'force', p.force, ...
            'axons', p.axons, 'downsample_t', p.downsample_t, 'downsample_xy', p.downsample_xy, ...
            'chunksize', chunksize, 'npcs', p.npcs, 'temporal_weight', p.temporal_weight, ...
            'smoothing_width', p.smoothing_width, 'spatial_threshold_sd', p.spatial_threshold_sd, ...
            'cellhalfwidth', p.cellhalfwidth, 'mergethreshold', p.mergethreshold, 'patchsize', p.patchsize, 'ncomponents', p.ncomponents, ...
            'minarea', p.minarea, 'maxarea', p.maxarea, 'overlap', p.overlap, 'crosscorr', p.crosscorr,'firstpctokeep',p.firstpctokeep);

        icaguidata.pars = p;
        save(savepath, 'icaguidata', '-v7.3');
        
        % Make it clickable by the javascript functions
        processForJavascript(mouse, date, runs, p.force, p.axons, p.server);
    end

    %% Follow-up with optional images for checking
    
    if p.pupil
        if ~p.job
            sbxPupilMasks(mouse, date, runs, p.server);
        end
        
        sbxPupils(mouse, date, runs, p.server);
    end
    
    if p.testimages
        for r = 1:length(runs)
            sbxFirstLast(mouse, date, runs(r), p.refsize, p.pmt, 'server', p.server);
            sbxStimulusTiff(mouse, date, runs(r), p.pmt, p.server);
        end

        sbxAlignAffineTest(mouse, date, runs, p.refpmt, p.server);
    end
end

