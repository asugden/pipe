function warp(obj, varargin)
% warp - Register the mean image of all days to each other using
% the imregdemons algorithm. 

%% Parse inputs
p = inputParser;
p.CaseSensitive = false;

% optional inputs
addOptional(p, 'n', 8); % sigma n, for first gaussian blurring kernel
addOptional(p, 'm', 30); % sigma m, for second gaussian blurring kernel
addOptional(p, 'edges', pipe.lab.badedges());

% parse
parse(p, varargin{:});
p = p.Results;
edges = p.edges;
obj.pars.edges = p.edges;

% Get movm for each day looping through last run of each day
sbxpath = pipe.path(obj.mouse, obj.initial_dates(1), obj.initial_runs{1}(end), 'sbx', obj.pars.server);
info = pipe.metadata(sbxpath);
sz = info.sz;
obj.pars.sz = sz;
nIm = length(obj.initial_dates);
NonReg_FOV = nan(sz(1), sz(2), nIm);
for i = 1:length(obj.initial_dates)

    % load first 1000 registered frames from each run and take mean
    movm = zeros(sz(1), sz(2));
    for k = 1:length(obj.initial_runs{i})
        path = pipe.path(obj.mouse, obj.initial_dates(i), ...
                  obj.initial_runs{i}(k), 'sbx', obj.pars.server);
        mov = mean(pipe.imread(path, 1, 1000, 1, [], 'register', true), 3);
        movm = movm + mov;
    end
    movm = movm./length(obj.initial_runs{i});

    % make the movm mean image pretty
    img = movm;
    img(img<0) = 0;
    img(isnan(img)) = 0;
    img = sqrt(img);
    img = img/max(img(:));
    img = adapthisteq(img);

    NonReg_FOV(:,:,i) = img;

end
pipe.io.write_tiff(NonReg_FOV, [obj.savedir filesep 'FOV_NONregistered_across_days'])

% crop and save 
NonReg_FOV_cropped2 = NonReg_FOV(edges(3):end-edges(4)-1,edges(1):end-edges(2)-1,:);
pipe.io.write_tiff(NonReg_FOV_cropped2,[obj.savedir filesep 'FOV_NONregistered_across_days_cropped']);

% preallocate AllWarpFields
for i = 1:nIm
    for j = 1:nIm
        AllWarpFields{i}{j} = [];
    end
end
% register
parfor curr_im = 1:nIm
    other_im_ind = setdiff(1:nIm, curr_im);
    
    % process image by blurring
    stack = NonReg_FOV_cropped2(:, :, other_im_ind);
    target = NonReg_FOV_cropped2(:, :, curr_im);
    f_prime = double(target) - double(imgaussfilt(target, p.n));
    g_prime = f_prime./(imgaussfilt(f_prime.^2, p.m).^(1/2));   
    target = g_prime;
    % set curr image warpfield to zeros
    AllWarpFields{curr_im}{curr_im} = zeros(sz(1), sz(2), 2);
    for i = 1:size(stack, 3)
        f_prime = double(stack(:, :, i)) - double(imgaussfilt(double(stack(:, :, i)), p.n));
        g_prime = f_prime./(imgaussfilt(f_prime.^2, p.m).^(1/2));
        stack(:, :, i) = g_prime;
    end

    for i = 1:size(stack,3)
        [D, ~] = imregdemons(stack(:, :, i), target, ...
            [700 700 700 700], ...
            'AccumulatedFieldSmoothing', 2.5, 'PyramidLevels', 4);
            
        % pad wirth zeros to get correct dimensions
        cols_remove_l = edges(1);
        cols_remove_r = edges(2);
        rows_remove_top = edges(3);
        rows_remove_bottom = edges(4);
        col_buffer_l = zeros(size(D,1),cols_remove_l,size(D,3));
        col_buffer_r = zeros(size(D,1),cols_remove_r,size(D,3));  
        
        % now buffer back in both dimensions
        WarpField = [col_buffer_l D col_buffer_r];
        row_buffer_top = zeros(rows_remove_top, size(WarpField,2), ...
                           size(WarpField,3));
        row_buffer_bottom = zeros(rows_remove_bottom, size(WarpField,2), ...
                           size(WarpField,3));
        WarpField = [row_buffer_top; WarpField; row_buffer_bottom];
        AllWarpFields{curr_im}{other_im_ind(i)} = WarpField;
    end
end

% now make Reg_FOV image
RegFOV = [];
for curr_im = 1:nIm
    curr_target = NonReg_FOV(:, :, curr_im);
    for i = 1:nIm
        tmp_reg_im = imwarp(NonReg_FOV(:, :, i), ...
                            AllWarpFields{curr_im}{i});
        tmpstack = cat(3, curr_target, tmp_reg_im);
        RegFOV = cat(3, RegFOV, tmpstack);
    end
end

% now write tiff of all mov reg to each other
chunk_size = nIm*2;
indtmp = 1;
for curr_day = 1:length(obj.initial_dates)
    save_dir_reg_im = [obj.savedir filesep 'Reg_FOV_each_target'];
    if ~exist(save_dir_reg_im, 'dir')
        mkdir(save_dir_reg_im)
    end
    pipe.io.write_tiff(RegFOV(:,:,indtmp:indtmp+chunk_size-1),[save_dir_reg_im filesep 'TargetFOV' num2str(curr_day)]);
    indtmp = indtmp + chunk_size;
end

% save
obj.warpdir = [obj.savedir filesep 'warpfields.mat'];
save(obj.warpdir, 'AllWarpFields', '-v7.3')
save([obj.savedir filesep 'xday_obj'],'obj','-v7.3')

% output for user
disp(['Registration (warping) done: Go to ' obj.savedir ])
disp('to select best warp (and identify any failed days).')

end