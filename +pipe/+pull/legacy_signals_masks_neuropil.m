function cellsort = legacy_signals_masks_neuropil(cellsort,expt,mouse,run)

delete_ROI_tag = 0;

% first lets identify those ROIs that have been labelled non ROIs and
% identify the pixels to not be included in any run
pix_to_not_include_anywhere = zeros(size(cellsort(1).mask));
ROI_to_eliminate_at_end = [];
ind_cells_remove = 1;
for i = 1:length(cellsort)
    if isfield(cellsort(i),'group_number') % to see if that category exists
        if cellsort(i).group_number == 5
            pix_to_not_include_anywhere = pix_to_not_include_anywhere + ...
                cellsort(i).mask > 0;
            ROI_to_eliminate_at_end = [ROI_to_eliminate_at_end i];
            cellsort_remove(ind_cells_remove) = cellsort(i);
            ind_cells_remove = ind_cells_remove + 1;
        end
    end
end
% now throw the cells to remove from the cellsort
cellsort(ROI_to_eliminate_at_end) = [];



%% Make binary masks
for i = 1:length(cellsort)
    % Only take top 75% of each weighted ROI
    tmpR = cellsort(i).mask;
    siz = size(tmpR);
    ind_mask = find(tmpR > 0);
    [tmpR2,ind_val] = sort(tmpR(ind_mask));
    ind_mask2 = ind_mask(ind_val);
    prctile_10 = prctile(tmpR2,25); % used to be 50 now taking top 75%
    
    ind_10 = find(tmpR2 > prctile_10,1,'First');
    tmpR2 = tmpR2(ind_10:end);
    ind_mask2 = ind_mask2(ind_10:end);
    tmpR3 = zeros(size(tmpR));
    tmpR3(ind_mask2) = tmpR2;
    cellsort(i).mask = tmpR3;
%     
	A = cellsort(i).mask > 0;
    % don't allow ROI to be in outer most pixel row of FOV
    A(1,:) = 0;
    A(end,:) = 0;
    A(:,1) = 0;
    A(:,end) = 0;
    % don't include any pixels that were eliminate in gui
    A(pix_to_not_include_anywhere > 0) = 0;
    cellsort(i).binmask = A;    
	cellsort(i).area = nnz(cellsort(i).binmask);
end

%% Make overlay cell image

% Dilate cells themselves so have protected ring
all_cells_dilated = zeros(size(cellsort(1).binmask));
for i = 1:length(cellsort);
    tmp = cellsort(i).binmask;
    if size(tmp,1) > 400 % this is for new 2p rig
        tmp = imdilate(tmp,[ones(10,10)]);
    else
        tmp = imdilate(tmp,[ones(4,4)]);
    end
    all_cells_dilated = all_cells_dilated + tmp;
end
all_cells_dilated = all_cells_dilated > 0;

% Dilation to get neuropil signal
overlap_image = zeros(size(cellsort(1).binmask));
for i = 1:numel(cellsort)
    if size(tmp,1) > 400 % this is for new 2p rig
        inner = imdilate(cellsort(i).binmask,[ones(15,15)]);
        outer = imdilate(cellsort(i).binmask,[ones(50,50)]);
    else
        inner = imdilate(cellsort(i).binmask,[ones(4,4)]);
        outer = imdilate(cellsort(i).binmask,[ones(18,18)]);
    end
    omi = outer - inner; % Have ring around actual axon and have neuropil outside this
    ind_overlap = find(omi == 1 & all_cells_dilated == 1); % Make sure neuropil doesn't overlap with dilated cell
    overlap_image(ind_overlap) = 4;
    omi(ind_overlap) = 0;
    % remove pixels excluded from both cellbodies and neuropil (group 5)
    omi(pix_to_not_include_anywhere > 0) = 0;
    cellsort(i).neuropil = logical(omi);
    if nnz(cellsort(i).neuropil)<50
        outer = imdilate(cellsort(i).binmask,[ones(50,50)]);
        omi = outer - inner; % Have ring around actual axon and have neuropil outside this
        ind_overlap = find(omi == 1 & all_cells_dilated == 1); % Make sure neuropil doesn't overlap with dilated cell
        overlap_image(ind_overlap) = 4;
        omi(ind_overlap) = 0;
        % remove pixels excluded from both cellbodies and neuropil (group 5)
        omi(pix_to_not_include_anywhere > 0) = 0;
        cellsort(i).neuropil = logical(omi);
    end
end

all_neuropil = zeros(size(cellsort(1).neuropil)); % Can Neuropil overlap with other neuropil
% figure;
for i = 1:length(cellsort)
	all_neuropil = all_neuropil + cellsort(i).neuropil;
end
% imagesc(all_neuropil)

all_cells_overlap = zeros(size(cellsort(1).binmask));
% To determine overlap image
for i = 1:length(cellsort)
	all_cells_overlap = all_cells_overlap + cellsort(i).binmask;
end

% remove all overlapping portions of ROI
ind_overlap = find(all_cells_overlap > 1);
overlap_image = zeros(size(cellsort(1).binmask));
overlap_image(ind_overlap) = 1;
% No longer dilating image before throwing out
overlap_image_dilated = imdilate(overlap_image,[ones(2,2)]);
overlap_image_dilated = overlap_image;
ind_overlap_dilated = find(overlap_image_dilated > 0);
ind_to_delete = [];
for i = 1:length(cellsort)
    clear tmp
    tmp = cellsort(i).binmask;
    tmp(ind_overlap_dilated) = 0;
    cellsort(i).binmask = tmp;
    % if this removes ROI then remove this from cellsort
    if max(max(cellsort(i).binmask)) == 0
        ind_to_delete = [ind_to_delete i];
    end
end
if delete_ROI_tag == 1
    cellsort(ind_to_delete) = []; 
end

all_cells = zeros(size(cellsort(1).binmask));
% figure;
for i = 1:length(cellsort)
	all_cells = all_cells + cellsort(i).binmask;
end

all_cells = all_cells > 0;
all_cells_undilated = all_cells;



%% Get centroids
% hold on
% 
for i = 1:length(cellsort)
	[rows, cols] = size(cellsort(i).binmask);

	y = 1:rows;
	x = 1:cols;

	[X, Y] = meshgrid(x,y);

	cellsort(i).centroid.x = mean(X(cellsort(i).binmask==1));
	cellsort(i).centroid.y = mean(Y(cellsort(i).binmask==1));
	
	plot(cellsort(i).centroid.x, cellsort(i).centroid.y, '.g');
	
end

all_neuropil = all_neuropil > 0;
figure
imagesc(all_neuropil+all_cells_undilated.*2);
for i = 1:numel(cellsort)
	text(cellsort(i).centroid.x, cellsort(i).centroid.y, num2str(i), 'color', [1 0 0],'FontSize',18);
end
if nargin > 1
    title([ date ' ' mouse ' run ' run ' ROI and Neuropil'])
%     print('-dtiff',[expt.dirs.analrootpn,'\',expt.name,'_ROI_and_neuropil']);
else
%     print('-dtiff',['ROI_and_neuropil']);
end    
if nargin > 1
    if exist('mov')
        mean_mov = mean(mov,3);
        writetiff(mean_mov.*all_cells_undilated,[expt.dirs.analrootpn '\all_ROI'])
    end
end
%% Adjust ica weights to scale with total pixel number ie will scale as if every pixes had weight of 1

for i = 1:length(cellsort);
    pix_w = cellsort(i).mask(cellsort(i).mask~=0);
    ind_pix = find(cellsort(i).mask~=0);
    pix_w = pix_w.*(length(pix_w)./sum(pix_w));
    cellsort(i).mask_norm = zeros(size(cellsort(i).mask));
    cellsort(i).mask_norm(ind_pix) = pix_w;
end

%% add an additional mask that is just the neuropil

max_ROIn = length(cellsort);
allfields = fieldnames(cellsort(1));
% preallocate all fields
for i = 1:length(allfields)
    cellsort(max_ROIn+1).(allfields{i}) = [];
end
% Now insert neuropil as mask
cellsort(max_ROIn+1).mask = all_neuropil > 0;
cellsort(max_ROIn+1).ica_segment = all_neuropil > 0;
cellsort(max_ROIn+1).neuropil = zeros(size(all_neuropil));
cellsort(max_ROIn+1).binmask = all_neuropil > 0;
cellsort(max_ROIn+1).area = nnz(all_neuropil>0);
% set ica trace = to last ica trace just so don't hit errors - same for
% centroid and 
cellsort(max_ROIn+1).ica_trace = cellsort(max_ROIn).ica_trace;
cellsort(max_ROIn+1).boundary = cellsort(max_ROIn).boundary;
cellsort(max_ROIn+1).centroid = cellsort(max_ROIn).centroid;

