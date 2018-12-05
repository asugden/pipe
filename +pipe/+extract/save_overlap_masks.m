function save_overlap_masks(path, masks, overlap)
%UNTITLED7 Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 3, overlap = 0.8; end
    
    overlaps = [];
    sums = zeros(1, length(masks));
    for m = 1:length(masks), sums(m) = sum(sum(masks{m})); end
    
    for m1 = 1:length(masks)
        for m2 = m1+1:length(masks)
            comb = sum(sum(bitand(masks{m1}, masks{m2})));
            if comb > sums(m1)*overlap || comb > sums(m2)*overlap
                overlaps = [overlaps m1 m2];
            end
        end
    end    

    fp = fopen(path, 'w');
    fprintf(fp, '{"overlaps":[');
    for i = 1:length(overlaps)/2
        if i > 1, fprintf(fp, ','); end
        fprintf(fp, '[%i,%i]', overlaps(2*i - 1), overlaps(2*i));
    end
    fprintf(fp, ']}');
    fclose(fp);
end

