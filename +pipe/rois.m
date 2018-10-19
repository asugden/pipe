function icaguidata = rois(movpaths, savepath, edges, varargin)
%SBXEXTRACTROIS Extract ROIs from a series of SBX files (easy to add TIFF
%   capabilities) and save into the icaguidata format of a '.ica' file at
%   savepath. movpaths should be a cell array, savepath is a path to which
%   '.ica' will be appended if it does not exist

    p = inputParser;
    addOptional(p, 'pmt', 1, @isnumeric);  % Which PMT to use for analysis, 1-green, 2-red
    addOptional(p, 'optolevel', []);  % The optotune level to extract-- if empty, all levels
    addOptional(p, 'type', 'pcaica');  % Can be 'nmf' or 'pcaica'. Will eventually add the ability for 'both'
    addOptional(p, 'force', false);  % Overwrite a save file if it already exists
    addOptional(p, 'axons', false);  % Set to true if running on axon data. Will be forced into PCA/ICA
    addOptional(p, 'downsample_t', 5);  % The number of pixels to downsample in time/frames
    addOptional(p, 'downsample_xy', 2);  % The number of pixels to downsample in space
    addOptional(p, 'chunksize', 1000);  % The size of a parallel chunk to be read in

    % PCA/ICA only
    addOptional(p, 'npcs', 1000, @isnumeric);  % The number of principal components to keep
                                               % WARNING: Divided by 4 for axons
    addOptional(p, 'firstpctokeep', 4, @isnumeric);
    addOptional(p, 'badframes', []);
    addOptional(p, 'temporal_weight', 0.1, @isnumeric);  % The temporal (versus spatial) weight for PCA. Default from Schnitzer was 0.5
    addOptional(p, 'smoothing_width', 2, @isnumeric);  % Standard deviation of Gaussian smoothing kernel (pixels)
                                                       % WARNING: Divided by 2 for axons
    addOptional(p, 'spatial_threshold_sd', 2, @isnumeric);  % Threshold for the spatial filters in standard deviations. Default from Schnitzer was 5
    
    % NMF only
    addOptional(p, 'cellhalfwidth', 2.5, @isnumeric);  % The half-width of cells in pixels
    addOptional(p, 'mergethreshold', 0.8, @isnumeric);  % The threshold for merging two ROIs that are neighboring
    addOptional(p, 'patchsize', -1, @isnumeric);  % Size of a patch to examine in parallel in pixels, calculated from cellhalfwidth
    addOptional(p, 'ncomponents', -1, @isnumeric);  % The number of rois to find in a patch, for advanced users only
    addOptional(p, 'minarea', 7, @isnumeric);  % The min area of a cell in pixels, will be pushed to 25 if left at 7 for PCA/ICA
    addOptional(p, 'maxarea', 500, @isnumeric);  % The max area of a cell in pixels, ignored for PCAICA unless different from 500
    addOptional(p, 'seeds', []);  % Seed locations for cells, replaces greedy algorithm
    
    % Parameters for both
    addOptional(p, 'overlap', 0.9, @isnumeric);  % The fraction of overlap allowed, combined with crosscorr
    addOptional(p, 'crosscorr', 0.9, @isnumeric);  % The fraction of correlation allowed, combined with overlap. The lower SNR of overlapping ROIs is removed
    addOptional(p, 'suffix', '.ica');  % Suffix to save into
    
    parse(p, varargin{:});
    p = p.Results;
    
    if ~strcmp(savepath(end-3:end), p.suffix), savepath = [savepath p.suffix]; end
    if ~p.force && exist(savepath, 'file')
        fprintf('icaquidata already exists: %s\n', savepath);
        return;
    end
    if p.axons, p.type = 'pcaica'; end
    if strcmpi(p.type(1:3), 'pca') && p.minarea == 7, p.minarea = 25; end
    
    %% Read in all files and combine them into a single movie
    
    if isnumeric(movpaths)
        mov = movpaths;
    else
        comb = cell(1, length(movpaths));
        totallen = 0;
        pipe.parallel();
        for r = 1:length(movpaths)
            path = movpaths{r};
            info = pipe.metadata(path);
            nframes = info.max_idx + 1;
            nchunks = ceil(nframes/p.chunksize);
            movpart = cell(1, nchunks);
            
            parfor c = 1:nchunks
                frames = pipe.imread(path, (c-1)*p.chunksize + 1, p.chunksize, ...
                    p.pmt, p.optolevel, 'register', true);
                frames = frames(edges(3):end-edges(4), edges(1):end-edges(2), :);
                frames = binxy(frames, p.downsample_xy);
                movpart{c} = bint(frames, p.downsample_t);
            end
            
            comb{r} = movpart;
            totallen = totallen + floor(nframes/p.downsample_t);
        end
        
        mov = zeros(size(comb{1}{1}, 1), size(comb{1}{1}, 2), totallen);
        f = 0;
        for r = 1:length(movpaths)
            for c = 1:length(comb{r})
                mov(:, :, f+1:f+size(comb{r}{c}, 3)) = comb{r}{c};
                f = f + size(comb{r}{c}, 3);
            end
        end
    end
    %% Extract ROIs
    
    if strcmp(p.type, 'nmf')
        if ~isempty(p.seeds)
            p.seeds(:, 1) = p.seeds(:, 1) - edges(3);
            p.seeds(:, 2) = p.seeds(:, 2) - edges(1);
            p.seeds = p.seeds/p.downsample_xy;
        end
        
        % Path is only required for where to put the matfile
        icaguidata = sbxPreprocessNMF(path, mov, 'cellhalfwidth', p.cellhalfwidth, ...
            'mergethreshold', p.mergethreshold, 'patchsize', p.patchsize, 'ncomponents', p.ncomponents, ...
            'minarea', p.minarea, 'maxarea', p.maxarea, ...
            'overlap', p.overlap, 'crosscorr', p.crosscorr, 'seeds', p.seeds, 'suffix', p.suffix);
    else
        maxarea = [];
        if p.maxarea ~= 500, maxarea = p.maxarea; end
        icaguidata = pipe.extract.pcaica(mov, 'axons', p.axons, ...
            'npcs', p.npcs, 'temporal_weight', p.temporal_weight, 'smoothing_width', p.smoothing_width, ...
            'spatial_threshold_sd', p.spatial_threshold_sd, 'minarea', p.minarea, 'maxarea', maxarea, ...
            'overlap', p.overlap, 'crosscorr', p.crosscorr, 'firstpctokeep', p.firstpctokeep,...
            'badframes', p.badframes);
    end
    
    p.edges = edges;
    icaguidata.pars = p;
    save(savepath, 'icaguidata', '-v7.3');
end

