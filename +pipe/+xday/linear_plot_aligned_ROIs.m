function linear_plot_aligned_ROIs(obj, cell_score_threshold)
% linear_plot_aligned_ROIs - plot and save a set of 
% all ROIs identified per cell across all time  

if nargin < 2 || isempty(cell_score_threshold)
    cell_score_threshold = 0;
end

%% Set path for saving
if isprop(obj, 'bridgealignment')
    stag = 'bridge';
elseif isprop(obj, 'xdayalignment')
    stag = 'xday';
end
xday_folder = [obj.savedir filesep 'single_cell_' stag '_alignments_' num2str(cell_score_threshold)];
if ~exist(xday_folder, 'dir')
    mkdir(xday_folder)
end

%% Load mean images, already warped
warped_images = pipe.io.read_tiff([obj.savedir '\FOV_registered_to_day_' num2str(obj.warptarget) '.tif']);

% get frame size
if ~isfield(obj.pars, 'sz')
    sbxpath = pipe.path(obj.mouse, obj.final_dates(1), obj.final_runs{1}(end), 'sbx', obj.pars.server);
    info = pipe.metadata(sbxpath);
    sz = info.sz;
else
    sz = obj.pars.sz;
end

%% Unpack masks
if isprop(obj, 'bridgealignment')
    % [master_masks] = UnwrapBridgeMasks(obj);
elseif isprop(obj, 'xdayalignment')
    % Unpack all masks into filtermask tensors
    master_masks = {};
    for i = 1:length(obj.final_dates)
        masks = obj.masks_original(:,:,i);
        top_ind = max(masks(:));
        masks_tensor = zeros(top_ind, sz(1), sz(2));
        for k = 1:top_ind
            bin_mask = masks == k;
            warp_mask = imwarp(bin_mask, obj.warpfields{i});
            warp_mask = warp_mask > 0;
            % Add a fabricated pixel to the top row of the image
            % if there is no mask. Ziv cannot handle empties
            if sum(warp_mask(:)) == 0
                disp(['Empty mask in day ' ...
                      num2str(obj.final_dates(i)) ...
                      ', ROI index ' num2str(k) ...
                      ', adding fake pixel...']);
                fake_pixel_ind = randi([1 sz(2)], 1, 1);
                warp_mask(1, fake_pixel_ind) = 1;
            end
            masks_tensor(k,:,:) = warp_mask;
        end
        master_masks{i} = masks_tensor; 
    end
end

%------------------------------------------------------------------------------
%% Set variables
% define minor variables/params 
frame = 20; % # pixels away from centroid to define corner of crop
crop = frame*2; % full size of cropped region

% define major variables
if isprop(obj, 'bridgealignment')
    xday_scores = obj.bridgealignment.cell_scores;
    my_ROIs = obj.bridgealignment.cell_to_index_map;
    mn_cent = obj.bridgealignment.registered_cells_centroids;
elseif isprop(obj, 'xdayalignment')
    xday_scores = obj.xdayalignment.cell_scores;
    my_ROIs = obj.xdayalignment.cell_to_index_map;
    mn_cent = obj.xdayalignment.registered_cells_centroids;
end
% threshold cells by quality of cross-day alignment
my_ROIs = my_ROIs(xday_scores >= 0,:); 
mn_cent = mn_cent(:,xday_scores >= 0);
% prevent NaN centroids from breaking plotting
nan_free_vec = ~isnan(sum(mn_cent,1));
my_ROIs = my_ROIs(nan_free_vec,:);
mn_cent = mn_cent(:,nan_free_vec);

% calculate the size of your image grid to match the aspect ratio of a 2p frame 
ratio = sz(1)/sz(2);
golden_num = sqrt(size(my_ROIs, 1)/ratio);
x_dim = ceil(golden_num);
y_dim = ceil(ratio*golden_num);
grid_size = [y_dim x_dim]; 
full_frame_size = grid_size*crop;

disp('Cropping masks:')
pad_sz = 50;
crop_masks = cell(1,size(my_ROIs, 2));
for day_num = 1:size(my_ROIs, 2)
    display_progress_bar('Terminating previous progress bars',true)
    display_progress_bar(['Cropping masks, set #1 - day #' num2str(day_num) ' '],false); 
    daily_masks = NaN(crop, crop, size(my_ROIs, 1));
    for cell_num = 1:size(my_ROIs, 1)
        if ~isnan(my_ROIs(cell_num, day_num)) && my_ROIs(cell_num, day_num) ~= 0
            ROI_ind = my_ROIs(cell_num, day_num);
            temp_cent = mn_cent(:,cell_num); % use the mean centroid to crop images
            x1 = temp_cent(1) - frame + pad_sz;
            y1 = temp_cent(2) - frame + pad_sz;
            tmp_mask = squeeze(master_masks{day_num}(ROI_ind,:,:));
            pad_mask = padarray(tmp_mask, [pad_sz pad_sz], 0, 'both'); % avoid edge issues by padding
            img = imcrop(pad_mask,[x1 y1 crop-1 crop-1]); % for some reason this is one pixel larger than crop so subtract 1
            daily_masks(:,:,cell_num) = img;
        end
        display_progress_bar(100*(cell_num)/size(my_ROIs, 1),false);
    end
    crop_masks{day_num} = daily_masks;
    display_progress_bar(' done',false);
end

% Reshape cropped maskes into grid

disp('Creating grid of masks:')
masks_grid = zeros([full_frame_size size(my_ROIs, 2)]); 
for day_num = 1:size(my_ROIs, 2)
    display_progress_bar('Terminating previous progress bars',true)
    display_progress_bar(['Creating grid, set #1 - day #' num2str(day_num) ' '],false);
    count = 1;
    frame_pos_x = 1:crop; 
    for down_ind = 1:y_dim
        frame_pos_y = 1:crop;
        for cross_ind = 1:x_dim
            if count > size(my_ROIs, 1)
                break % break out of loops if you have added all cells 
            end
            masks_grid(frame_pos_x, frame_pos_y, day_num) = crop_masks{day_num}(:,:,count);
            frame_pos_y = frame_pos_y + crop;
            display_progress_bar(100*(count)/size(my_ROIs, 1),false);
            count = count + 1; 
        end
        frame_pos_x = frame_pos_x + crop;
    end
    display_progress_bar(' done',false);
end

%------------------------------------------------------------------------------
%% Make cropped images matrix and crop into grid 

disp('Cropping mean images:')
pad_sz = 50;
crop_images = cell(1,size(my_ROIs, 2));
for day_num = 1:size(my_ROIs, 2)
    display_progress_bar('Terminating previous progress bars',true)
    display_progress_bar(['Cropping mean images - day #' num2str(day_num) ' '],false); 
    daily_masks= NaN(crop, crop, size(my_ROIs, 1));
    for cell_num = 1:size(my_ROIs, 1)
        temp_cent = mn_cent(:, cell_num); % use the mean centroid to crop images
        x1 = temp_cent(1) - frame + pad_sz;
        y1 = temp_cent(2) - frame+ pad_sz;
        pad_warp = padarray(warped_images(:,:,day_num), [pad_sz pad_sz], 0, 'both');
        img = imcrop(pad_warp,[x1 y1 crop-1 crop-1]);
        daily_masks(:,:,cell_num) = img;
        display_progress_bar(100*(cell_num)/size(my_ROIs, 1),false);
    end
    crop_images{day_num} = daily_masks;
    display_progress_bar(' done',false);
end

% reshape cropped images into grid
disp('Creating grid of mean images:')
images_grid = zeros([full_frame_size size(my_ROIs, 2)]); 
for day_num = 1:size(my_ROIs, 2)
    display_progress_bar('Terminating previous progress bars',true)
    display_progress_bar(['Creating grid - day #' num2str(day_num) ' '],false);
    count = 1;
    frame_pos_x = 1:crop; 
    for down_ind = 1:y_dim
        frame_pos_y = 1:crop;
        for cross_ind = 1:x_dim
            if count > size(my_ROIs, 1)
                break % break out of loops if you have added all cells 
            end
            images_grid(frame_pos_x, frame_pos_y, day_num) = crop_images{day_num}(:,:,count);
            frame_pos_y = frame_pos_y + crop;
            display_progress_bar(100*(count)/size(my_ROIs, 1),false);
            count = count + 1; 
        end
        frame_pos_x = frame_pos_x + crop;
    end
    display_progress_bar(' done',false);
end

%------------------------------------------------------------------------------
%% Set your coloring scheme 
% make cropped alpha grid matrix

disp('Creating grid of GREEN alpha masks for each cell:')
cell_color = [0.1 0.8 0]; %green
alpha_small = cat(3, cell_color(1,1)*ones(crop,crop*size(my_ROIs, 2)), ...
                    cell_color(1,2)*ones(crop,crop*size(my_ROIs, 2)), ...
                cell_color(1,3)*ones(crop,crop*size(my_ROIs, 2)));
% for some reason there is an extra row, so remove
alpha_small = alpha_small(1:end-1,:,:);

%------------------------------------------------------------------------------
%% Reshape and plot 

% set plotting variables
down = 1;
across = 0;
transparency_factor = 0.4;
skippers = find(xday_scores < obj.LowestCellScoreThreshold);
true_ind = find(nan_free_vec); % actual "absolute" ROI ID acounting for nans 

% plot
figure('Units', 'normalized' ,'Position',[0 0.5 1 .11]) 
for ROI_num = 1:size(my_ROIs, 1)

    if ismember(ROI_num, skippers)
        continue
    end

    across = across + 1;
    crange = (1+crop*(across - 1)):(crop*(across));
    if max(crange) > full_frame_size
        down = down + 1;
        across = 1;
        crange = (1+crop*(across - 1)):(crop*(across));
    end
    rrange = (1+crop*(down - 1)):(crop*(down)); % for some reason there is an extra row, so remove
    img = images_grid(rrange,crange, :);
    img = reshape(img, [crop crop*size(my_ROIs, 2)]);
    msk = masks_grid(rrange,crange, :);
    msk = reshape(msk, [crop crop*size(my_ROIs, 2)]);
    % for some reason there is an extra row, so remove
    msk = msk(1:end-1,:);
    img = img(1:end-1,:);

    % plot image
    imagesc(img);
    colormap('gray')
    axis image
    axis off
    hold on
    title(['ROI #' num2str(true_ind(ROI_num)) '  score ' num2str(xday_scores(true_ind(ROI_num)))])

    % overlay masks
    n = imagesc(alpha_small);
    set(n,'AlphaData',(msk>0).*transparency_factor)

    % save
    print([xday_folder filesep 'ROI_' num2str(true_ind(ROI_num))], '-dpng');

    % clear last figure to prevent making lots of figures 
    clf
    hold off
end

end
