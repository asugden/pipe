function mask = erosionmask(filter, erosion, connected)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 3, connected = true; end
    
    % Get only those values involved in mask
    flatnan = filter(:);
    vals = sort(flatnan(flatnan ~= 0));
    
    mn = abs(min(vals)) + 1;
    filter(filter == 0) = NaN;
    filter = filter + mn;
    filter(isnan(filter)) = 0;
    
    % Find the threshold and binarize the mask
    if erosion > 1
        thresh = 0.0000001;
    else
        n = round(erosion*length(vals));
        if n > length(vals), n = length(vals); end
        if n < 1, n = 1; end
        thresh = vals(end - n + 1);
    end

    mask = filter(:, :);
    mask(mask < thresh) = 0;
    mask(mask > 0) = 1;
        
    % Only pay attention to the smallest ROI
    if connected && erosion < 2
        cc = bwconncomp(mask);
        if cc.NumObjects > 1
            [~, mxpos] = max(filter(:));
            [y, x] = ind2sub(size(filter), mxpos);
            maskfill = imfill(logical(mask - 1), [y x]);
            mask = logical(mask) & maskfill;
        end
    end

    % Fill in 'hole' pixels
    mask = imfill(logical(mask), 'holes');
end

