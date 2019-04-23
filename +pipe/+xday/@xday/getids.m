function getids(obj, varargin)
% Create MOUSE_DATE_crossday-cell-ids.txt files in each date dir
% containing a unique cell ID for each cell aligned across days.
% Input can be any type of alignment object or structure or if
% empty will prompt user to select one of these objects. Uses 
% .cell_to_index_map field from crossday alignment to assign IDs. 

%% Parse inputs
p = inputParser;
p.CaseSensitive = false;

% default params
addOptional(p, 'save_tag', []);  % -- Add additional text to distinguish distinct alignments
addOptional(p, 'force', false);  % -- Don't save over existing files by default

% parse
parse(p, varargin{:});
p = p.Results;

% if save_tag is included ensure that the first character is a "-" for readability
if ~isempty(p.save_tag)
    if ~strcmpi(p.save_tag(1), '-') || ~strcmpi(p.save_tag(1), '_')
        p.save_tag = sprintf('%s%s', '-', p.save_tag);
    end
end

% get alignment variables
index_map = obj.xdayalignment.cell_to_index_map;
cell_scores = obj.xdayalignment.cell_scores;
metadata = p.track.metadata;
masks = obj.masks_original;

%% Loop through days and create file with unique IDs
% index_map is a cells (rows) x days (cols) matrix where
% row is a unique cell ID and the value is the index of the
% cell from a .signals (or equivalent) file 
novel_id = size(index_map, 1) + 1;
for i = 1:size(index_map, 2)

    % clear_IDs at each loop start
    cell_IDs = [];
    align_scores = [];

    % set save path for each date
    id_path = sprintf( ...
        '%s%s%s_%i_crossday-cell-ids%s.txt', ...
        pipe.lab.datedir(obj.mouse, obj.final_dates(i), obj.pars.server), ...
        filesep, obj.mouse, obj.final_dates(i), p.save_tag);
    sc_path = sprintf( ...
        '%s%s%s_%i_crossday-cell-scores%s.txt', ...
        pipe.lab.datedir(obj.mouse, obj.final_dates(i), obj.pars.server), ...
        filesep, obj.mouse, obj.final_dates(i), p.save_tag);

    % only continue if you are forcing save or file does not exist
    if exist(id_path, 'file')
        if ~p.force
            disp('force=false, this file already exists:')
            disp(['    ' idpath])
            return
        end
    end
    
    % get your unique cell IDs from index_map
    icells = index_map(index_map(:,i) > 0,i);
    iscores = cell_scores(index_map(:,i) > 0);
    [args, arginds] = sort(icells, 'ascend');
    qc = length(1:args(end)) - length(icells);
    idcells = find(index_map(:,i));
    cell_IDs(args) = idcells(arginds);
    align_scores(args) = iscores(arginds);

    % edge case: add zeros to end if cells were missed at end
    day_masks = masks(:,:,i);
    if length(cell_IDs) < max(day_masks(:))
        mismatch = max(day_masks(:)) - length(cell_IDs);
        for k = 1:mismatch
            cell_IDs = [cell_IDs 0];
            align_scores = [align_scores 1]; % assumes single cell (perfect alignment)
        end
    end

    % check for cells that were dropped in xday alignment and 
    % assign them IDs
    if sum(cell_IDs == 0) > 0 || qc ~= 0 
        for k = find(cell_IDs == 0)
            cell_IDs(k) = novel_id;
            warning(['Day ' num2str(i) ': ' num2str(qc) ...
                    ' cells not aligned. Assigning new unique ID: ' ...
                    num2str(novel_id) '.'
                    ])
            novel_id = novel_id + 1;
        end
    end

    % write file with unique cell IDs
    f = fopen(id_path, 'w');
    fprintf(f, '%09i\r\n',cell_IDs);
    fclose(f);

    % write file with cell scores
    f = fopen(sc_path, 'w');
    fprintf(f, '%.3f\r\n', align_scores);
    fclose(f);
end

end  % main function end