function [optimal_cell_to_index_map, registered_cells_centroids, centroid_locations_corrected, cell_scores, cell_scores_positive, cell_scores_negative, cell_scores_exclusive, p_same_registered_pairs, all_to_all_p_same_centroid_distance_model, centroid_distances_distribution, p_same_centers_of_bins, uncertain_fraction_centroid_distances, cdf_p_same_centroid_distances, false_positive_per_distance_threshold, true_positive_per_distance_threshold] = CellRegAuto(allFiltersMats, microns_per_pixel)

% DESCRIPTION:
% A cell registration method based on CellReg by Sheintuch et al.,
% Cell Reports, 2017 (doi: 10.1016/j.celrep.2017.10.013), beginning
% with a set of cell masks aligned by a separate proprietary method and
% using CellReg's model calculation and two-step cell registration
% features.
%
% DEPENDENCIES:
% These are files from Sheintuch et al., 2017 CellReg directory used in
% this cell registration function, in order of appearance.
%   - compute_centroid_locations
%   - estimate_number_of_bins
%   - compute_data_distribution
%   - compute_centroid_distances_model
%   - estimate_registration_accuracy
%   - compute_p_same
%   - initial_registration_centroid_distances
%   - cluster_cells
%   - transform_distance_to_similarity
%   - compute_scores
%
% INPUTS:
% - allFiltersMats
%       S-length cell array where each cell contains the mask images for
%       all cells found in that session and where S is the number of
%       sessions
%
% - microns_per_pixel
%       Scalar value specifying the diameter in real space of each pixel
%       in the mask images
%
% OUTPUTS:
% - optimal_cell_to_index_map
%       CxS matrix giving final the mapping of cell number to the indices
%       of the masks that correspond to that cell, where C is the number of
%       cells identified and S is the number of sessions
%
% - registered_cells_centroids
%       2xC matrix giving the x-y coordinates of the centroid of each
%       cell, the mean coordinates of the masks that have been registered
%       as that cell
%
% - centroid_locations_corrected
%       Sx1 cell array where each entry is an Nx2 matrix giving the x-y
%       coordinates of the centroid of each mask, where N is the
%       number of masks found in that session
%
% - cell_scores
%       C-length vector giving the registration score of each cell
%
% - uncertain_fraction_centroid_distances
%       proportion of mask pairs whose registration is less than 95%
%       confident
%
% - p_same_registered_pairs
%       1xC cell array where each cell is an SxS matrix containing the
%       p_same value for each pair of masks registered to that cell
%
% - all_to_all_p_same_centroid_distance_model
%       matrix containing p_same value for every possible pair of masks
%       from the masks given as input
%
% - cell_scores_positive
% - cell_scores_negative
% - cell_scores_exclusive
% - centroid_distances_distribution
% - p_same_centers_of_bins
% - cdf_p_same_centroid_distances
% - false_positive_per_distance_threshold
% - true_positive_per_distance_threshold
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin < 3 || isempty(max_distance), max_distance = 12; end

% registration parameters
%microns_per_pixel;
p_same_threshold = 0.5;
maximal_distance = max_distance;
imaging_technique = 'two_photon';

% extract spatial footprints and calculate centroids
spatial_footprints_corrected = allFiltersMats;
[centroid_locations_corrected] = compute_centroid_locations(spatial_footprints_corrected, microns_per_pixel);
disp(''); disp('---> Preliminary processing complete'); disp('');

% parameters for probabilistic model
normalized_maximal_distance = maximal_distance / microns_per_pixel;
p_same_certainty_threshold = 0.95; % "certain cells" are those with p_same > threshld or p_same < (1-threshold)
[~, centers_of_bins] = estimate_number_of_bins(spatial_footprints_corrected, normalized_maximal_distance);
disp(''); disp('---> Calculating probabilistic model'); disp('');

% computing correlations and distances across days 
[all_to_all_indexes, ~, all_to_all_centroid_distances, ~, neighbors_centroid_distances, ~, ~, ~, ~, ~, ~] = ...
        compute_data_distribution(spatial_footprints_corrected, centroid_locations_corrected, normalized_maximal_distance);

% modeling the distribution of centroid distances
[~, p_same_given_centroid_distance, centroid_distances_distribution, centroid_distances_model_same_cells, centroid_distances_model_different_cells, ~, ~, centroid_distance_intersection] = ...
    compute_centroid_distances_model(neighbors_centroid_distances, microns_per_pixel, centers_of_bins);

% estimating registration accuracy for 2-photon microscopy
[p_same_centers_of_bins, uncertain_fraction_centroid_distances, cdf_p_same_centroid_distances, false_positive_per_distance_threshold, true_positive_per_distance_threshold] = ...
    estimate_registration_accuracy(p_same_certainty_threshold, neighbors_centroid_distances, centroid_distances_model_same_cells, centroid_distances_model_different_cells, p_same_given_centroid_distance, centers_of_bins);
disp(''); disp('---> Registering cells'); disp('');

% computing the P_same for each neighboring cell-pair by the centroid model
[all_to_all_p_same_centroid_distance_model] = ...
        compute_p_same(all_to_all_centroid_distances, p_same_given_centroid_distance, centers_of_bins, imaging_technique);

% computing the initial registration according to a simple threshold
centroid_distances_distribution_threshold = centroid_distance_intersection / microns_per_pixel;
[cell_to_index_map, ~, ~] = ...
    initial_registration_centroid_distances(normalized_maximal_distance, centroid_distances_distribution_threshold, centroid_locations_corrected);

% registering the cells with the clustering algorithm
transform_data = false;
registration_approach = 'Probabilistic';
[optimal_cell_to_index_map, registered_cells_centroids, cell_scores, cell_scores_positive, cell_scores_negative, cell_scores_exclusive, p_same_registered_pairs] = ...
    cluster_cells(cell_to_index_map, all_to_all_p_same_centroid_distance_model, all_to_all_indexes, normalized_maximal_distance, p_same_threshold, centroid_locations_corrected, registration_approach, transform_data);
disp('done.');

end









