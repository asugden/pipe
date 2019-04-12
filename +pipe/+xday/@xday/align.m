function align(obj)
% Run the CellReg algorithm to align masks across 
% days. Apply calculated warp registration to masks
% for each day and pass to CellRegAuto (script to run
% CellReg with no GUI. 

% get frame size
if ~isfield(obj.pars, 'sz')
    sbxpath = pipe.path(obj.mouse, obj.final_dates(1), obj.final_runs{1}(end), 'sbx', obj.pars.server);
    info = pipe.metadata(sbxpath);
    sz = info.sz;
else
    sz = obj.pars.sz;
end

% Get all masks for all days
masks_original = zeros(sz(1), sz(2), length(obj.final_dates));
for i = 1:length(obj.final_dates)
    date = obj.final_dates(i);
    run = obj.final_runs{i}(end);
    simp = pipe.load(obj.mouse, date, run, 'simpcell', ...
               obj.pars.server);
    masks_original(:,:,i) = (simp.masks');
end

% Unpack all masks into filtermask tensors and 
% flattened warped masks
filtermasks = {};
masks_warped = zeros(sz(1), sz(2), length(obj.final_dates));
for i = 1:length(obj.final_dates)
    masks = masks_original(:,:,i);
    top_ind = max(masks(:));
    masks_tensor = zeros(sz(1), sz(2), top_ind);
    for k = 1:top_ind
        bin_mask = masks == k;
        warp_mask = imwarp(bin_mask, obj.warpfields{i});
        warp_mask = warp_mask > 0;
        % Add a fabricated pixel to the top row of the image
        % if there is no mask. Ziv cannot handle empties
        if sum(warp_mask(:)) == 0
            disp(['Empty mask in day ' ...
                  num2str(obj.final_dates(i)) ...
                  ', ROI index ' num2str(k) ...
                  ', adding fake pixel...']);
            fake_pixel_ind = randi([1 sz(2)], 1, 1);
            warp_mask(1, fake_pixel_ind) = 1;
        end
        masks_tensor(:,:,k) = warp_mask;
        masks_warped = masks_warped.*(warp_mask == 0);
        masks_warped = masks_warped + (warp_mask.*k);
    end
    filtermasks{i} = masks_tensor; 
end

% populate properties
obj.masks_original = masks_original;
obj.masks_warped = masks_warped;

% ensure that pixel_size is set
if isempty(obj.pixelsize_microns)
    obj.pixelsize_microns = 1.54;
    disp('obj.PixelSize_microns was unset, automatically set to 1.54 ...')
    disp('1.4x zoom with 16x objective is ~1.54 microns per pixel on Hutch ...')
end

% run cellreg (ziv algo)
[ ...
optimal_cell_to_index_map, ...
registered_cells_centroids, ...
centroid_locations_corrected, ...
cell_scores, ...
cell_scores_positive, ... 
cell_scores_negative, ...
cell_scores_exclusive, ...
p_same_registered_pairs, ...
all_to_all_p_same_centroid_distance_model, ...
centroid_distances_distribution, ...
p_same_centers_of_bins, ...
uncertain_fraction_centroid_distances, ...
cdf_p_same_centroid_distances, ...
false_positive_per_distance_threshold, ...
true_positive_per_distance_threshold ...
] = pipe.xday.CellRegAuto(filtermasks, obj.pixelsize_microns);

% create aligned data structure
xdayalignment.cell_to_index_map = optimal_cell_to_index_map;
xdayalignment.registered_cells_centroids = registered_cells_centroids;
xdayalignment.centroid_locations_corrected = centroid_locations_corrected;
xdayalignment.cell_scores = cell_scores;
xdayalignment.cell_scores_positive = cell_scores_positive;
xdayalignment.cell_scores_negative = cell_scores_negative;
xdayalignment.cell_scores_exclusive = cell_scores_exclusive;
xdayalignment.p_same_registered_pairs = p_same_registered_pairs;
xdayalignment.centroid_distances_distribution = centroid_distances_distribution;
xdayalignment.p_same_centers_of_bins = p_same_centers_of_bins;
xdayalignment.uncertain_fraction_centroid_distances = uncertain_fraction_centroid_distances;
xdayalignment.cdf_p_same_centroid_distances = cdf_p_same_centroid_distances;
xdayalignment.false_positive_per_distance_threshold = false_positive_per_distance_threshold;
xdayalignment.true_positive_per_distance_threshold = true_positive_per_distance_threshold;
xdayalignment.all_to_all_p_same_centroid_distance_model = all_to_all_p_same_centroid_distance_model;

% populate properties
obj.xdayalignment = xdayalignment;

% save object
save([obj.savedir filesep 'xday_obj'],'obj','-v7.3')

end