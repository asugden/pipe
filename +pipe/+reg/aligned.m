function data = aligned(path, regpath, k, N, pmt, optolevel)
%ALIGNED Aligns a chunk of a file based on regpath
%   Input:
%       path - path to .sbx file, .sbx automatically appended if not there
%       startframe - first frame to read, 1-indexed
%       nframes - number of frames to read
%       tform - a cell array of affine2d transforms to apply first
%       dft - a vector of size(nframes, 4) of dft registration to apply
%       pmt - which color to read, 0 if only one color, 1 if two colors
%           and red
%       [removeedges] - remove the edges before returning, T/F
%   Output:
%       data - an array of size(height, width, min(nframes, max possible))
%           of data that has been registered with affine and dft transforms

    if nargin < 5, pmt = 1; end
    if nargin < 6, optolevel = []; end
    
    % Load image data and registration data
    data = pipe.imread(path, k, N, pmt, optolevel);
    info = pipe.metadata(path);
    reg = load(regpath, '-mat');
    
    % Get the positions to return, accounting for optotune levels
    pos = k:k + size(data, 3) - 1;
    if ~isempty(optolevel) && info.optotune_used
        pos = optotune_level:length(info.otwave):info.nframes;
        pos = pos(pos >= k);
        pos = pos(pos <= k + size(data, 3));
    end
    
    if isfield(reg, 'tform')
        tform = reg.tform(pos);

        for j = 1:size(data, 3)
            data(:, :, j) = imwarp(data(:, :, j), tform{j}, 'OutputView', imref2d(size(data(:, :, j))));
        end
    end
    
    if isfield(reg, 'trans') && (~isfield(reg, 'binframes') || reg.binframes > 1)
        c = class(data);
        
        [nr, nc] = size(fft2(double(data(:, :, 1))));
        Nr = ifftshift(-fix(nr/2):ceil(nr/2)-1);
        Nc = ifftshift(-fix(nc/2):ceil(nc/2)-1);
        [Nc, Nr] = meshgrid(Nc, Nr);
        
        trans = reg.trans(pos, :);
        for j = 1:size(data, 3)
            row_shift = trans(j, 3);
            col_shift = trans(j, 4);
            diffphase = trans(j, 2);

            fftslice = fft2(double(data(:, :, j)));
            frame = fftslice.*exp(1i*2*pi*(-row_shift*Nr/nr - col_shift*Nc/nc));
            frame = frame*exp(1i*diffphase);
            data(:, :, j) = cast(abs(ifft2(frame)), c);
        end
    end
end

