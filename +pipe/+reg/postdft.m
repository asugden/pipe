function translation = postdft(mov_path, startframe, ...
    nframes, ref, tform, pmt, otlevel, edges)
%POSTDFT Apply a dft transformation after an affine transformation

    % Parameters -----------------------
    upsample = 100;
    cut_borders = 0.15;
    % ----------------------------------
    
    % Read in data
    data = pipe.imread(mov_path, startframe - 1, nframes, pmt, otlevel);
    translation = zeros(size(data, 3), 4);
    
    % Reduce size for DFT registration
    data = data(edges(3)+1:end-edges(4), edges(1)+1:end-edges(2), :);
    red = floor(size(data)*cut_borders);
    ref = ref(red(1):end-red(1), red(2):end-red(2));
    
    % DFT registration
    target_fft = fft2(double(ref));
    blank_affine = [1 0 0; 0 1 0; 0 0 1];
    for i = 1:size(data, 3)
        data_affine = imwarp(data(:, :, i), tform{i}, 'OutputView',...
            imref2d(size(data(:, :, i))));
        data_affine = data_affine(red(1):end-red(1), red(2):end-red(2));
        data_fft = fft2(double(data_affine));
        [dftoutput, ~] = pipe.reg.dftcore(target_fft, data_fft, upsample);
        translation(i, :) = dftoutput;
    end
end