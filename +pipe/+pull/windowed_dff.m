function cellsort = windowed_dff(cellsort, fps, time_window, percentile)
% WINDOWED_DFF Get the dff trace and axon dff trace from a cellsort and
%   add it to the cellsort.

    % time window: moving window of X seconds - calculate f0 at time window prior to each frame - used to be 32
    if nargin < 3, time_window = 32; end
    if nargin < 4, percentile = 10; end

    nframes = length(cellsort(1).timecourse.raw);
    nrois = size(cellsort, 2);

    % Calculate f0 for each timecourse using a moving window of time window
    % prior to each frame
    f0 = zeros(nrois, nframes);
    windowframes = round(time_window*fps);

    % create temporary traces variable that allows you to do the prctile
    % quickly
    traces_f = nan(nrois, length(cellsort(1).timecourse.subtracted));
    for curr_ROI = 1:nrois
        traces_f(curr_ROI, :) = cellsort(curr_ROI).timecourse.subtracted;
    end

    pipe.parallel();
    pool_siz = 8;

    % how many ROIs per core
    nROIs_per_core = ceil(nrois/pool_siz);
    ROI_vec = 1:nROIs_per_core.*pool_siz;
    ROI_blocks = unshuffle_array(ROI_vec,nROIs_per_core);
    ROI_start_points = ROI_blocks(:,1);
    parfor curr_ROI_ind = 1:pool_siz
        ROIs_to_use = ROI_blocks(curr_ROI_ind,:)
        ROIs_to_use(ROIs_to_use > nrois) = [];
        % pre-allocate
        f0_vector_cell{curr_ROI_ind} = nan(length(ROIs_to_use),nframes);
        for i = 1:nframes
            if i <= windowframes
                frames = traces_f(ROIs_to_use,1:windowframes);
                f0 = prctile(frames,percentile,2);
            else
                frames = traces_f(ROIs_to_use,i - windowframes:i-1);
                f0 = prctile(frames,percentile,2);
            end
            f0_vector_cell{curr_ROI_ind}(:,i) = f0;
        end
    end

    % Reshape into correct structure
    for curr_ROI_ind = 1:pool_siz
        ROIs_to_use = ROI_blocks(curr_ROI_ind,:);
        ROIs_to_use(ROIs_to_use > nrois) = [];
        f0(ROIs_to_use,:) = f0_vector_cell{curr_ROI_ind};
    end

    traces_dff = (traces_f-f0)./ f0;

    % Stick back into cellsort variable
    for curr_ROI = 1:nrois
        cellsort(curr_ROI).timecourse.f0_axon = f0(curr_ROI,:);
        cellsort(curr_ROI).timecourse.dff_axon = traces_dff(curr_ROI,:);
    end
end

