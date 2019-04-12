function image = unshuffle_array(image, unshuffle_number)
    % Unshuffle in Matlab
    sz = size(image);
    image = reshape(image, unshuffle_number, sz(2)/unshuffle_number); 
    image = image';
end