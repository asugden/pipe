function save_trace_image(path, trace, zeropos)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 3, zeropos = 5; end

    fig = figure('Visible', 'Off', 'units', 'pixels', 'outerposition', [0, 0, 1600, 400]);
    plot(trace, 'k');
    
    % Get x and Y limits
    xlim([1 length(trace)]);
    
    mx = max(trace);
    mn = min(trace);
    if mn > 0, mn = 0; end
    if mx < 0, mx = 0; end

    pmx = max(mx, -1*mn*zeropos);
    pmn = min(mn, -1*mx/zeropos);
    ylim([pmn pmx]);

    % Get rid of extraneous plotting junk
    axesHandles = findall(fig, 'type', 'axes');
    set(axesHandles, 'position', [0 0 1.0 1.0]);
    set(gca, 'xtick', []);
    set(gca, 'ytick', []);
    set(gca, 'visible', 'off');
    set(gcf, 'PaperUnits', 'inches', 'PaperPosition', [0, 0, 16, 4]);

    % Save
    print('-djpeg', '-r100', path);
    close(fig);

end

