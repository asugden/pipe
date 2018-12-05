function icaguidata = pcaica(mov, varargin)
%SBXPREPROCESSPCAICA Extract ROIs using PCA ICA from Mukamel and Schnitzer
%   Updated 170914
    p = inputParser;
    addOptional(p, 'axons', false);  % Set to true if running on axon data
    addOptional(p, 'npcs', 1000, @isnumeric);  % The number of principal components to keep
                                               % WARNING: Divided by 4 for axons
    addOptional(p, 'firstpctokeep', 4, @isnumeric);
    addOptional(p, 'badframes', []);
    addOptional(p, 'temporal_weight', 0.1, @isnumeric);  % The temporal (versus spatial) weight for PCA. Default from Schnitzer was 0.5
    addOptional(p, 'smoothing_width', 2, @isnumeric);  % Standard deviation of Gaussian smoothing kernel (pixels)
                                                       % WARNING: Divided by 2 for axons
    addOptional(p, 'spatial_threshold_sd', 2, @isnumeric);  % Threshold for the spatial filters in standard deviations. Default from Schnitzer was 5
    addOptional(p, 'minarea', 25, @isnumeric);  % Minimum area for an ROI in pixels
    addOptional(p, 'maxarea', [], @isnumeric);  % Maximum area for an ROI in pixels
    addOptional(p, 'overlap', 0.9, @isnumeric);  % The fraction of overlap allowed, combined with crosscorr
    addOptional(p, 'crosscorr', 0.9, @isnumeric);  % The fraction of correlation allowed, combined with overlap. The lower SNR of overlapping ROIs is removed
    parse(p, varargin{:});
    p = p.Results;

    if p.axons, p.npcs = round(p.npcs/4); end
    if p.axons, p.smoothing_width = round(p.smoothing_width/2); end
    
    % Do the PCA first
    [mixedsig, mixedfilters, CovEvals, ~, meanimg, ~] = ...
        pipe.extract.pca_schnitzer(mov, p.npcs, p.badframes);

    % 2b. Plot PC spectrum
    last_pc_above_noise = pipe.extract.pc_noise(mov, CovEvals);

    % Discard first three PCs because they are likely to contain full-field
    % effects:
    usepcs = p.firstpctokeep:last_pc_above_noise; % used to be 4:

    % 3a. ICA
    nIC = length(usepcs);

    [ica_sig, ica_filters, ica_A, numiter] = ...
        pipe.extract.ica_schnitzer(mixedsig, mixedfilters, CovEvals, usepcs, p.temporal_weight, nIC);

    % Normalise ICA_filters such that they are not negative...may not make
    % super much sense but I got this from the original CellsortSegmentation
    % function:
    ica_filters = (ica_filters - mean(ica_filters(:)))/abs(std(ica_filters(:)));

    % MJLM 4. segment
    arealims = p.minarea;
    if ~isempty(p.maxarea)
        arealims = [p.minarea p.maxarea];
    end
    [ica_segments, segmentlabel, segcentroid] = pipe.extract.pca_segmentation(ica_filters, ...
        p.smoothing_width, p.spatial_threshold_sd, arealims, 0, p.axons);

    % Get segment time series
    segment_sig = pipe.extract.pcaica_apply_filter(mov, ica_segments, [], meanimg, 1);    
    
    % First, sort all of those variables that have been selected for
    % keeping
    %nrois = length(ica_segments);
    nrois = size(ica_segments,1); % AL changed on 170914
    sortmatrix = zeros(nrois, 2);
    for t = 1:nrois, sortmatrix(t, 1) = pipe.proc.dffsnr(segment_sig(t, :)); end  % DFF SNR sort metric
    sortmatrix(:, 2) = 1:nrois;
    matlabver = version('-release');
    matlabver = str2num(matlabver(1:end-1));
    if matlabver < 2017
        sortmatrix = sortrows(sortmatrix, -1);
    else
        sortmatrix = sortrows(sortmatrix, [1], 'descend');
    end
    sortorder = sortmatrix(:, 2);
    
    % Then iterate through traces and throw out those that overlap and are
    % highly correlated, keeping the first sort
    detrendtr = segment_sig(:, :);
    for t = 1:nrois, detrendtr(t, :) = detrend(detrendtr(t, :)); end
    
    masks = logical(zeros(size(mov, 1), size(mov, 2), nrois));
    for r = 1:nrois
        masks(:, :, r) = (squeeze(ica_segments(r, :, :)) > 0);
    end
    
    [sortorder, included] = pipe.extract.remove_overlaps(detrendtr, masks, sortorder, p.overlap, p.crosscorr);

    % Make the legacy icaguidata variable
    icaguidata.movm = meanimg;
    icaguidata.movcorr = pipe.extract.crosscorr_image(pipe.proc.bint(mov, 100));
    icaguidata.snrsort = sortmatrix(included, 1);
    for i = 1:length(sortorder)
        tr = sortorder(i);
        icaguidata.ica(i).filter = squeeze(ica_segments(tr, :, :));
        icaguidata.ica(i).trace = segment_sig(tr, :);
    end
end

