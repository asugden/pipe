function registered = dft_and_apply(mov, target_mov)
%SBXALIGNTURBOREGCORE aligns a file (given by path) using ImageJ's TurboReg
%   NOTE: hardcoded path to ImageJ.

    % Shared between xrun and within run
    % Get the sizes of the files
    dft_transforms = zeros(size(mov, 3), 4);
    registered = zeros(size(mov));

    % Match the binning of the target to the data
    target_fft = fft2(double(target_mov));
    
    % Iterate over all times
    for i = 1:size(mov, 3)
        data_fft = fft2(double(mov(:, :, i)));
        dft_transforms(i, :) =  pipe.reg.dftcore(target_fft, data_fft, 100);
    end
    
    c = class(mov);
    [nr, nc] = size(fft2(double(mov(:, :, 1))));
    Nr = ifftshift(-fix(nr/2):ceil(nr/2)-1);
    Nc = ifftshift(-fix(nc/2):ceil(nc/2)-1);
    [Nc, Nr] = meshgrid(Nc, Nr);

    for j = 1:size(mov, 3)
        row_shift = dft_transforms(j, 3);
        col_shift = dft_transforms(j, 4);
        diffphase = dft_transforms(j, 2);

        fftslice = fft2(double(mov(:, :, j)));
        frame = fftslice.*exp(1i*2*pi*(-row_shift*Nr/nr - col_shift*Nc/nc));
        frame = frame*exp(1i*diffphase);
        registered(:, :, j) = cast(abs(ifft2(frame)), c);
    end
end

