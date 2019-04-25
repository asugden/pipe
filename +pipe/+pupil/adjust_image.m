function [eye, mask] = adjust_image(eye, mask, emission, bin, max_intensity, chunksize)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 3, emission = true; end
    if nargin < 4, bin = 2; end
    if nargin < 5, max_intensity = 160; end
    if nargin < 6, chunksize = 1000; end 
    
    if bin > 1
        eye = pipe.proc.binxy(double(eye));
        mask = pipe.proc.binxy(mask);
        mask(mask < 1) = 0;
        mask = logical(mask);
    end
    
    nframes = size(eye, 3);
    nchunks = ceil(nframes/chunksize);
    ceye = cell(1, nchunks);
    
    for c = 1:nchunks
        mx = min(c*chunksize, nframes);
        ceye{c} = eye(:, :, (c-1)*chunksize+1:mx);
    end

    % Get the current parallel pool and register
    pipe.parallel();
    parfor c = 1:nchunks
        for frame = 1:size(ceye{c}, 3)
            ceye{c}(:, :, frame) = regionfill(ceye{c}(:, :, frame), ~mask);
            ceye{c}(:, :, frame) = ceye{c}(:, :, frame) - min(ceye{c}(:, :, frame));
            scale = max_intensity/max(max(ceye{c}(:, :, frame)));
            ceye{c}(:, :, frame) = ceye{c}(:, :, frame)*scale;
            
            if ~emission
                ceye{c}(:, :, frame) = max_intensity - ceye{c}(:, :, frame);
            end
            
            ceye{c}(:, :, frame) = imgaussfilt(ceye{c}(:, :, frame), 0.75); 
        end
    end

    % Recombine to a vector
    for c = 1:nchunks
        mx = min(c*chunksize, nframes);
        eye(:, :, (c-1)*chunksize+1:mx) = ceye{c};
    end
    
    eye = uint8(eye);
end

