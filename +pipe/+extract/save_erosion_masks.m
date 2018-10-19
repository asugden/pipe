function [maskinds, erosions] = save_erosion_masks(path, filter, erosions, connected)
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 4, connected = true; end
    
    % Sort erosions so that we can build up masks
    erosions = sort(erosions);
    erosions = [erosions 2.0];
    
    % Get only those values involved in mask
    masks = cell(1, length(erosions));
    maskinds = cell(1, length(erosions));
    
    % Write the beginning of the json file, if desired
    if ~isempty(path)
        fp = fopen(path, 'w');
        fprintf(fp, '{"erosions":[');
        for i = 1:length(erosions)
            if i > 1, fprintf(fp, ','); end
            fprintf(fp, '%.2f', erosions(i));
        end
        fprintf(fp, '],\n"masks":[');
    end
    
    for i = 1:length(erosions)
        mask = pipe.extract.erosionmask(filter, erosions(i), connected);
        
        for j = 1:i-1
            mask = mask - masks{j};
        end
        masks{i} = mask;
        
        % Make a list of x, y indices that make up the mask
        for x = 1:size(mask, 2)
            for y = 1:size(mask, 1)
                if masks{i}(y, x) > 0
                    maskinds{i} = [maskinds{i} x y];
                end
            end
        end
        
        % Write the indices, if desired
        if ~isempty(path)
            if i > 1, fprintf(fp, ','); end
            fprintf(fp, '[');
            for j = 1:length(maskinds{i})
                if j > 1, fprintf(fp, ','); end
                fprintf(fp, '%i', maskinds{i}(j));
            end
            fprintf(fp, ']');
        end
    end
    
    % Write the end and close the file, if desired
    if ~isempty(path)
        fprintf(fp, ']}'); 
        fclose(fp);
    end
end

