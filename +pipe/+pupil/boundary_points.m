function [epx, epy, threshold_below_minimum] = boundary_points( ...
    frame, mask, sx, sy, edge_thresh, rays)
%BOUNDARY_POINTS Return all boundary points for a particular frame of a 
% pupil movie.

    if nargin < 5, edge_thresh = 40; end % Gradient change in ray for edgepoint, set to match image scaling
    if nargin < 6, rays = 24; end        % Relatively arbitary, reset by code

    expand_edge = 1;                     % Expand the edges by this value, set on real data
    min_feature_candidates = 6;          % Minimum number of pupil feature candidates
    
    im_size = size(frame);
    while 1
        [epx, epy, threshold_below_minimum] = pipe.pupil.starburst( ...
            frame, sx, sy, edge_thresh,...
            rays, min_feature_candidates, 'dec');

        if ~isempty(epx)
            linearInd = sub2ind(im_size, epy, epx);

            % only keep epx and epy within pdiam mask
            epx = epx(mask(linearInd));
            epy = epy(mask(linearInd));
        end

        % check if have enough samples to run ransac, if not adjust
        % parameters to try to get enough points
        if length(unique(epx)) >= 5 && length(unique(epy)) >= 5
            break
        elseif edge_thresh >= 6
            edge_thresh = edge_thresh - 1;
        elseif rays < 60
            rays = rays + 1;
        else
            break;
        end
    end

    if isempty(epx) || length(epx) < 5, return; end

    % expand endpoints slightly to better fit pupil
    epx(epx < sx) = epx(epx < sx) - expand_edge;
    epx(epx > sx) = epx(epx > sx) + expand_edge;
    epy(epy < sy) = epy(epy < sy) - expand_edge;
    epy(epy > sy) = epy(epy > sy) + expand_edge;

    % add rand amounts to slightly vary pixel values
    rand_edge = rand(1, numel(epx)) - 0.5;
    epx = epx + rand_edge(1:length(epx));
    epy = epy + rand_edge(1:length(epy));

end

