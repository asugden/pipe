function im = crosscorr_image(mov, w)
% SBXPREPROCESSCROSSCOREIMAGE Makes a cross-correlation image from a movie
%   downsampled in time and space that can be used for cell-clicking.
    % Downloaded by Rohan from File Exchange

    % mov is temporally and spatially downsampled movie
    % w is the window size over which to compute correlations

    if nargin < 2, w = 20; end

    % Initialize and set up parameters
    ymax = size(mov, 1);
    xmax = size(mov, 2);
    nframes = size(mov, 3);
    im = zeros(ymax, xmax);

    for y = 1+w:ymax-w
        for x = 1+w:xmax-w
            % Extract center pixel's time course and subtract its mean
            cpix = reshape(mov(y, x, :) - mean(mov(y, x, :), 3), [1 1 nframes]);
            ad_a = sum(cpix.*cpix, 3);  % Auto corr, for normalization later

            % Neighborhood
            a = mov(y-w:y+w, x-w:x+w,:);  % Extract the neighborhood
            b = mean(mov(y-w:y+w, x-w:x+w,:), 3);  % Get its mean
            nmean = bsxfun(@minus, a, b);  % Subtract its mean
            ad_b = sum(nmean.*nmean, 3);  % Auto corr, for normalization later

            % Cross corr with normalization
            ccs = sum(bsxfun(@times, cpix, nmean), 3)./sqrt(bsxfun(@times, ad_a, ad_b));
            ccs((numel(ccs) + 1)/2) = [];  % Delete the middle point
            im(y, x) = mean(ccs(:));  % Get the mean cross corr of the local neighborhood
        end
    end
end

