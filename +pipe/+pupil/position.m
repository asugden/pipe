function [dx, dy, area, radii, quality] = position(eye, mask, cx, cy, varargin)
%SBXPUPILPOSITION Code thanks to David Brann, 2017. Take in a movie of an 
%   eye in 3D along with a pupil mask, apply the mask to the movie, and
%   determine the x and y positions along with the area and quality. The
%   quality is a combination of the number of points used to fit and
%   whether the edge threshold is too low.

    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'draw', false);        % Draw images for testing
    addOptional(p, 'emission', true);     % True if pupil is brighter than sclera
    addOptional(p, 'interactive', true);  % If interactive, fix missed steps. Otherwise, error
    addOptional(p, 'outlier_sigma', 5);   % The number of sigmma considered an outlier
    
    % Image parameters
    addOptional(p, 'bin_xy', 2);          % Movie binning, for speed and noise
    addOptional(p, 'max_intensity', 160); % Optimizes for ransac
    addOptional(p, 'chunksize', 1000);    % Chunk movie scaling, and ransac if desired
    addOptional(p, 'single_centroid', false); % If true, can parallelize.
    
    % RANSAC parameters
    addOptional(p, 'residual_threshold', 10); 
    addOptional(p, 'new_center_weight', 0.05);       % Ratio for how much to adjust the center each frame
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;

    %% Initialize parameters
    
    if isempty(cx) || isempty(cy)
        if ~p.interactive
            error('Eye position centers not set for first frame.');
        end
        
        imagesc(eye(:, :, 1), [0 100]);
        title('Select the center of the eye');
        [sx, sy] = ginput(1);
        close(gcf());
        ecen = [sx sy];
    else
        ecen = [cx cy];
    end

    nframes = size(eye, 3);

    % Output parameters
    dx = [];
    dy = [];
    area = [];
    radii = [];
    quality = [];
    
    % Set up image
    [eye, mask] = pipe.pupil.adjust_image(eye, mask, p.emission, p.bin_xy, ...
        p.max_intensity, p.chunksize);
    ecen = ecen/p.bin_xy;

    %% DRAW
    % Fit each frame or every 100th frame if drawing
    
    if p.draw
        hfig = figure;
        img = imagesc(eye(:, :, 1));
        hold on;
        sx = ecen(1);
        sy = ecen(2);
        epx = sx; epy = sy;
        h = plot(epx, epy, 'w*');

        x = sx; y = sy;
        h1 = plot(x, y, 'r-');
        h2 = plot(sx, sy, 'bo');
        
        for i = 1:100:size(eye, 3)
            frame = eye(:, :, i);
            
            [epx, epy, toolow] = pipe.pupil.boundary_points(frame, mask, ecen(1), ecen(2));
            if isempty(epx) || length(epx) < 5, continue; end

            [best_model, best_inliers, xy, num_inliers] = pipe.pupil.ransac_ellipse([epx; epy], ecen, ...
                p.residual_threshold, [], [], 0);
            if isempty(best_model), continue; end
            
            % Plot, if desired
            set(img,'CData',frame);
            hold on;
            set(h, 'YData', epy, 'XData', epx); % updating data this way is fast to plot
            set(h1, 'YData', xy(2,:), 'XData', xy(1,:));
            set(h2, 'YData', best_model(2), 'XData', best_model(1));
            title(i);
            drawnow;
        end
    end
    
    %% RUN
    
    nframes = size(eye, 3);
    nchunks = ceil(nframes/p.chunksize);
    ceye = cell(1, nchunks);
    chunkparams = cell(1, nchunks);
    
    for c = 1:nchunks
        mx = min(c*p.chunksize, nframes);
        ceye{c} = eye(:, :, (c-1)*p.chunksize+1:mx);
        chunkparams{c} = cell(size(ceye{c}, 3), 1);
    end
    
    % Could optionally dilate mask inwards for safety, as Yoav did
    pipe.parallel();
    parfor c = 1:nchunks
        for i = 1:size(ceye{c}, 3)
            frame = ceye{c}(:, :, i);

            [epx, epy, toolow] = pipe.pupil.boundary_points(frame, mask, ecen(1), ecen(2));
            if isempty(epx) || length(epx) < 5
                fprintf('Could not find enough points, skipping \n');
                chunkparams{c}{i} = NaN(1, 7);
                continue;
            end

            [best_model, best_inliers, xy, num_inliers] = pipe.pupil.ransac_ellipse([epx; epy], ecen, ...
                p.residual_threshold, [], [], 0);
            if isempty(best_model)
                fprintf('Could not find enough points, skipping \n');
                chunkparams{c}{i} = NaN(1, 7);
                continue;
            end

            chunkparams{c}{i} = [best_model, num_inliers, toolow];
        end
    end
    
    % Put output back together... thanks matlab.
    parmatrix = [];
    for c = 1:nchunks
        cparmatrix = cat(1, chunkparams{c}{:});
        parmatrix = cat(1, parmatrix, cparmatrix);
    end

    %% Combine into correct output
    
    % Set the quality score correctly
    qmed = nanmedian(parmatrix(:, 6));
    parmatrix(parmatrix(:, 6) > 2*qmed, 6) = 0;
    parmatrix(:, 6) = parmatrix(:, 6)./nanmedian(parmatrix(:, 6));
    parmatrix(isnan(parmatrix(:, 6)), 6) = 0;
    parmatrix(parmatrix(:, 7) == 1, 6) = 0;
    whrat = parmatrix(:, 3)./parmatrix(:, 4);
    parmatrix(whrat > 4, 6) = 0;
    parmatrix(whrat < 0.25, 6) = 0;
    
    quality = parmatrix(:, 6)';
    
    % Fix beginning
    if sum(parmatrix(1:3, 6) < 0.25) > 0
        epos = 3 + find(parmatrix(4:end, 6) > 0.25, 1);
        for i = 1:size(parmatrix, 2)
            parmatrix(1:epos, i) = parmatrix(epos, i);
        end
    end
    
    % Interpolate over bad regions
    npos = find(parmatrix(:, 6) < 0.25, 1);
    while ~isempty(npos)
        epos = npos + find(parmatrix(npos + 2:end - 4, 6) > 0.25, 1) + 2;
        
        if isempty(epos)
            for i = 1:size(parmatrix, 2)
                parmatrix(npos - 2:end, i) = parmatrix(npos - 3, i);
            end
        else
            while epos + 6 < size(parmatrix, 1) && ~isempty(find(parmatrix(epos+1:epos+5, 6) < 0.25, 1))
                epos = epos + find(parmatrix(epos+3:end - 4, 6) > -1, 1) + 3;
                if isempty(epos), epos = size(parmatrix, 1); end
            end
            
            % No idea what this does- fixing error
            if epos + 3 > size(parmatrix, 1), epos = size(parmatrix, 1) - 3; end
            
            % Interpolate each parmatrix line
            for i = 1:size(parmatrix, 2)
                binterp = parmatrix(npos - 3, i);
                einterp = parmatrix(epos + 3, i);

                ninterp = (epos + 2) - (npos - 2) + 1;
                newdata = interp1([0 ninterp + 1], [binterp einterp], 1:ninterp);
                parmatrix(npos - 2:epos + 2, i) = newdata';
            end
        end
        
        npos = npos + find(parmatrix(npos:end - 4, 6) < 0.25, 1);
    end
    
    dx = [0 diff(parmatrix(:, 1)')];
    dy = [0 diff(parmatrix(:, 2)')];
    area = pi*parmatrix(:, 3)'.*parmatrix(:, 4)';
    radii = [parmatrix(:, 3)'; parmatrix(:, 4)'];
    
    dx = p.bin_xy*dx;
    dy = p.bin_xy*dy;
    area = p.bin_xy*p.bin_xy*area;
    radii = p.bin_xy*radii;
    
    %% Remove outliers
    
    % Smooth slightly
    area = movmedian(area, 5);
    
    % Calculate a moving mean
    nframes = length(area);
    baseline = zeros(1, nframes);
    baseline(:) = nan;
    chunksize = 1000;
    nchunks = ceil(nframes/chunksize);
    
    while nframes - (nchunks-1)*chunksize < 10
        chunksize = chunksize + 2;
        nchunks = ceil(nframes/chunksize);
    end
    
    for c = 1:nchunks
        mn = (c - 1)*chunksize + 1;
        mx = min(c*chunksize, nframes);
        val = nanmean(area(mn:mx));
        baseline(mn + floor(chunksize/2.0)) = val;
        
        if c == 1
            baseline(1:mn + floor(chunksize/2.0)) = val;
        elseif c == nchunks
            baseline(mn + floor(chunksize/2.0):nframes) = val;
        end
    end
    baseline = fillmissing(baseline, 'spline');
    
    % Use the moving mean to find outliers
    tarea = area - baseline;
    stdev = std(tarea);
    outliers = abs(tarea) > p.outlier_sigma*stdev;
    outliers = conv(outliers, ones(5, 1), 'same');
    outliers(outliers > 0) = 1;
    outliers = logical(outliers);
        
    % Fill in outlier positions
    area(outliers) = NaN;
    area = fillmissing(area, 'linear');
end

