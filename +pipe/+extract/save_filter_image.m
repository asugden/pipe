function [cx, cy, ran] = save_filter_image(path, im, minim)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 3, minim = 20; end

    xdim = sum(im, 1);
    ydim = sum(im, 2);

    mnx = find(xdim > 0, 1, 'first');
    mxx = find(xdim > 0, 1, 'last');
    mny = find(ydim > 0, 1, 'first');
    mxy = find(ydim > 0, 1, 'last');

    cx = round(mean([mnx mxx]));
    cy = round(mean([mny mxy]));
    rx = mxx - mnx;
    ry = mxy - mny;
    ran = ceil(max([rx ry minim])/2.0);

    smallim = padarray(im, [ran ran], NaN);
    smallim = smallim(cy:cy+2*ran, cx:cx+2*ran);
    smallim(smallim == 0) = NaN;
    smallim = smallim/max(max(smallim));

    R = smallim(:, :);
    G = smallim(:, :);
    B = smallim(:, :);

    R(isnan(smallim)) = 0.56;
    G(isnan(smallim)) = 0.76;
    B(isnan(smallim)) = 0.83;

    clrim = zeros(size(R, 1), size(R, 2), 3);
    clrim(:, :, 1) = R;
    clrim(:, :, 2) = G;
    clrim(:, :, 3) = B;

    fig = figure('Visible', 'Off');
    imagesc(clrim);

    axesHandles = findall(fig, 'type', 'axes');
    set(axesHandles, 'position', [0 0 1.0 1.0]);
    set(gca, 'xtick', []);
    set(gca, 'ytick', []);
    set(gca, 'visible', 'off');
    set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0, 0, 2, 2]);

    % Save
    print('-dpng', '-r100', path);
    close(fig);
end

