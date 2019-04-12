function cellsort = upsample_masks(cellsort, imagesz, removededges, binning)
% UPSAMPLEMASKS Correct for the fact that the masks are downsampled in
%   space for PCA/ICA
    
    % Initialize cellsort mask variable and protect against empty masks
    for i = 1:length(cellsort)
        % Edge removal values from pipe.lab.badedges
        if i == 1
            left_col_buffer = zeros(size(cellsort(i).mask, 1), floor(removededges(1)/binning));
            right_col_buffer = zeros(size(cellsort(i).mask, 1), ceil(removededges(2)/binning));
            xsize = size(cellsort(i).mask, 2) + floor(removededges(1)/binning) + ceil(removededges(2)/binning);
            top_row_buffer = zeros(floor(removededges(3)/binning), xsize);
            bot_row_buffer = zeros(ceil(removededges(4)/binning), xsize);
        end
        
        % Buffer back in both dimensions and spatially upsample
        cellsort(i).mask = [left_col_buffer cellsort(i).mask right_col_buffer];
        cellsort(i).mask = [top_row_buffer; cellsort(i).mask; bot_row_buffer];
        cellsort(i).mask = imresize(cellsort(i).mask, imagesz, 'nearest');
        
        % Buffer in both dimensions for weights and spatially upsample
        cellsort(i).weights = [left_col_buffer cellsort(i).weights right_col_buffer];
        cellsort(i).weights = [top_row_buffer; cellsort(i).weights; bot_row_buffer];
        cellsort(i).weights = imresize(cellsort(i).weights, imagesz, 'nearest');
    end

end

