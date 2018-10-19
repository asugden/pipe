function [covmat, mov, movm, movtm] = t_covariance(mov, pixw, pixh, nt)
    %-----------------------
    % Load movie data to compute the temporal covariance matrix
    npix = pixw*pixh;
    mov = reshape(mov, npix, nt);

    % DFoF normalization of each pixel
    movm = mean(mov, 2); % Average over time
    movmzero = (movm == 0); % Avoid dividing by zero
    movm(movmzero) = 1;
    mov = mov ./ (movm*ones(1, nt)) - 1;
    mov(movmzero, :) = 0;

    c1 = (mov'*mov)/npix;
    movtm = mean(mov, 1); % Average over space
    covmat = c1 - movtm'*movtm;
    clear c1 
end