function out = bint(data, bin)
%BINT Bin a movie along the third dimension with factor bin

    if nargin < 2, out = data; return; end
    if bin < 2, out = data; return; end

    if bin > size(data, 3)
        out = mean(data, 3);
        return;
    end
    
    [y, x, t] = size(data);
    t = floor(t/bin)*bin;
    out = data(:, :, 1:t);
    
    out = reshape(out, y*x, t)';
    out = mean(reshape(out, bin, []), 1);
    out = shiftdim(reshape(out, t/bin, y, x), 1);
end
