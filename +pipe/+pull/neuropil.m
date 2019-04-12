function out = neuropil(cellsort)
% GETNEUROPIL get the neuropil for each cell and the combined neuropil
%   accounting for overlapping cells and neuropil/cell overlaps

    % Dilate cells so that neuropil is subtracted only from an annulus
    cellarea = zeros(size(cellsort(1).mask));
    for i = 1:length(cellsort)
        cellarea = cellarea + imdilate(cellsort(i).mask, [ones(10, 10)]);
    end
    cellarea = cellarea > 0;

    % Dilation to get neuropil signal
    npil_all = logical(zeros(size(cellsort(1).mask))); %#ok<LOGL>
    cell_overlaps = zeros(size(cellsort(1).mask));
    
    % Create the initial neuropil
    for i = 1:numel(cellsort)
        cellsort(i).mask = logical(cellsort(i).mask);
        if ~isfield(cellsort(i), 'group_number') || cellsort(i).group_number >= 0
            % Create a neuropil annulus
            inner = imdilate(cellsort(i).mask, [ones(15, 15)]);
            outer = imdilate(cellsort(i).mask, [ones(50, 50)]);
            npil = logical(outer - inner); % Have ring around actual axon and have neuropil outside this
            npil = and(npil, not(cellarea));
            cellsort(i).neuropil = npil;

            % Broaden the neuropil if it is too small
            if nnz(cellsort(i).neuropil) < 50
                outer = imdilate(cellsort(i).mask, [ones(50, 50)]);
                npil = logical(outer - inner);
                npil = and(npil, not(cellarea));
                cellsort(i).neuropil = npil;
            end

            % Keep track of the combined neuropil and the overlaps of cells
            % The cell overlaps will be subtracted later
            npil_all(cellsort(i).neuropil) = 1;
            cell_overlaps(cellsort(i).mask) = cell_overlaps(cellsort(i).mask) + 1;
        end
    end
    cell_overlaps = cell_overlaps > 2;
    
    %% Go over the previous masks and make them final, saving only ROIs 
    % with nonzero areas
    out = struct();
    nrois = 1;
    for i = 1:numel(cellsort)
        % Remove overlaps
        cellsort(i).mask = and(cellsort(i).mask, not(cell_overlaps));
        
        % Keep only cells with nonzero areas
        if sum(sum(cellsort(i).mask)) > 0 && ...
                (~isfield(cellsort(i), 'group_number') || cellsort(i).group_number >= 0)
            if nrois == 1
                out = cellsort(i);
            else
                out(nrois) = cellsort(i);
            end
            
            % Make sure that weights include only selected pixels
            out(nrois).weights(~out(nrois).mask) = 0;
            
            % And scale weights to be equal to every pixel having a weight
            % of 1
            out(nrois).weights = out(nrois).weights*sum(out(nrois).mask(:)) ...
                /sum(out(nrois).weights(:));
            
            nrois = nrois + 1;
        end
    end

    %% Add a neuropil-only mask at the end
    
    out(nrois).mask = npil_all;
    out(nrois).trace = [];
    out(nrois).weights = npil_all;

end