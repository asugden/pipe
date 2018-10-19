function im = averaget(mov)
%AVERAGET Average a matrix across the third dimension
    [w h t] = size(mov);
    im = reshape(mov, [w*h t]);
    im = mean(im, 2);
    im = reshape(im, [w h]);
end

