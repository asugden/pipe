function [covmat, mov, movm, movtm] = x_covariance(mov, pixw, pixh, nt)
    %-----------------------
    % Load movie data to compute the spatial covariance matrix
    npix = pixw*pixh;
    mov = reshape(mov, npix, nt);

    % DFoF normalization of each pixel
    movm = mean(mov, 2); % Average over time
    movmzero = (movm == 0);
    movm(movmzero) = 1;
    mov = mov ./ (movm * ones(1, nt)) - 1; % Compute Delta F/F
    mov(movmzero, :) = 0;

    movtm = mean(mov, 2); % Average over space
    clear movmzeros

    c1 = (mov*mov')/size(mov, 2);
    covmat = c1 - movtm*movtm';
    clear c1
end