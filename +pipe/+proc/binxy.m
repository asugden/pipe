function binned = binxy(mov, factor)
%BINXY Adapted from Rohan's binning script, bins only in XY

    if nargin < 2, factor = 2; end
    factor = round(factor);

    [y, x, nframes] = size(mov);
    
    % Remove edge pixels if necessary
    if mod(x, factor), x = x - mod(x, factor); end
    if mod(y, factor), y = y - mod(y, factor); end
    mov = mov(1:y, 1:x, :);

    % Turn movie into 2-D vector
    mov = reshape(mov, y, x*nframes);
    [m, n] = size(mov);

    % Bin along columns:
    mov = mean(reshape(mov, factor, []), 1);

    % Bin along rows:
    mov = reshape(mov, m/factor, []).'; %Note transpose
    mov = mean(reshape(mov, factor, []), 1);
    mov = reshape(mov, n/factor, []).'; %Note transpose 

    % Turn back into original shape:
    binned = reshape(mov, y/factor, x/factor, nframes);
end

