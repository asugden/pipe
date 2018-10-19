function save_scaled_image(path, im)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

    % Start the figure
    fig = figure('Visible', 'Off');
    colormap('Gray');

    % Set the intensity
    im(im < 0) = 0;
    im(isnan(im)) = 0;
    im = sqrt(im);
    im = im/max(im(:));
    im = adapthisteq(im);
    mx = min(max(max(im)), 2.5*median(double(nonzeros(im))));
 
    % Draw image
    imagesc(im, [0 mx]);
    xlim([0 size(im, 2)])
    ylim([0 size(im, 1)])

    % Remove axis borders
    axesHandles = findall(fig, 'type', 'axes');
    set(axesHandles, 'position', [0 0 1.0 1.0]);
    set(gca, 'xtick', []);
    set(gca, 'ytick', []);
    set(gca, 'visible', 'off');
    set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0, 0, size(im, 2), size(im, 1)]);

    % Save
    print('-djpeg', '-r1', path);
    close(fig);
end

