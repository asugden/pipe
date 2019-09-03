function out = bint(data, bin)
%BINT Bin a movie along the third dimension with factor bin

    if nargin < 2, out = data; return; end
    if bin < 2, out = data; return; end

    if bin > size(data, ndims(data))
        out = mean(data, ndims(data));
        return;
    end
    
    if ndims(data) == 3
        [y, x, t] = size(data);
        t = floor(t/bin)*bin;
        out = data(:, :, 1:t);

        out = reshape(out, y*x, t)';
        out = mean(reshape(out, bin, []), 1);
        out = shiftdim(reshape(out, t/bin, y, x), 1);
    elseif ismatrix(data)
        [y, t] = size(data);
        t = floor(t/bin)*bin;
        out = data(:, 1:t);

        out = reshape(out, y, t)';
        out = mean(reshape(out, bin, []), 1);
        out = shiftdim(reshape(out, t/bin, y), 1);
    end
end
