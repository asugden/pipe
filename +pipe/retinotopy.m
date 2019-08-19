function images = retinotopy(path)
%RETINOTOPY Determine visual locations of brain regions on Hutch
%   Can use path to movie file or directory
%   Corrects location of visual regions so that lateral is left

    baseline_sec = [-1 0];
    gcamp_stim_sec = [0 2];
    intrinsic_stim_sec = [2 8];
    n_bars = 4;  % Number of bars per type
    framerate = 15;  % Jeff: where is this defined?

    % Top is lateral
    % Bottom is medial
    % Left is anterior
    % Right is posterior
    
    %% Find appropriate files
    [path, ~, ~] = fileparts(path);  % Jeff: change this to just pass the containing folder? As is you need to pick an arbitrary file in the folder.
    
    ml = [];
    evs = [];
    path_mov = '';
    
    fs = dir(path);
    for i = 1:length(fs)
        [~, filename, ext] = fileparts(fs(i).name);
        if strcmp(ext, '.bhv')
            path_ml = fullfile(path, [filename ext]);
            ml = pipe.io.read_bhv(path_ml);
        elseif strcmp(ext, '.mj2_events')
            path_evs = fullfile(path, [filename ext]);
            evs = pipe.io.read_sbxevents(path_evs);
            if evs(1) == 0, evs = evs(2:end); end
        elseif strcmp(ext, '.mj2')
            path_mov = fullfile(path, [filename ext]);
        end
    end
    
    if isempty(ml)
        error('Monkeylogic file not found (.bhv)');
    elseif isempty(evs)
        error('XEvents file not found (.mj2_events)');
    elseif isempty(path_mov)
        error('Epifluorescence movie not found (.mj2)');
    end

    %% Check if is intrinsic
%     intrinsic = false;
    intrinsic = contains(ml.TimingFiles{1}, 'Retinotopy_noise_int');  % Jeff: This is speific to our exact files, but seems ok?
    
    bl_start = round(baseline_sec(1)*framerate);
    bl_frames = round((baseline_sec(2) - baseline_sec(1))*framerate);
    
    if intrinsic
        disp('Using intrinsic timings.');
        epi_start = round(intrinsic_stim_sec(1)*framerate);
        epi_frames = round((intrinsic_stim_sec(2) - intrinsic_stim_sec(1))*framerate);
    else
        epi_start = round(gcamp_stim_sec(1)*framerate);
        epi_frames = round((gcamp_stim_sec(2) - gcamp_stim_sec(1))*framerate);
    end
    
    %% Separate events
    
    % Interlace horizontal, then vertical
    events = {};  % Horz1 is on top, Vert1 is on left
    conditions = ml.ConditionNumber(1:length(evs));
    
    for i = 1:n_bars
        cond = condition_number(ml, i, true);
        events{2*(i - 1) + 1} = evs(conditions == cond);
        
        cond = condition_number(ml, i, false);
        events{2*(i - 1) + 2} = evs(conditions == cond);
    end
    
    %% Registration pieces
    
    fprintf('Registering target movie\n');
    reg = pipe.io.read_sbxepi(path_mov, 500, 500);
    target = pipe.proc.averaget(reg);
    target = pipe.proc.averaget(pipe.reg.dft_and_apply(reg, target));   
    
    %% Average movie
    
    mean_im = [];
    images = cell(1, 8);
    for i = 1:length(events)
        fprintf('Reading movie frames for condition %i\n', i);
        tic;
        for ev = events{i}
            bl = pipe.io.read_sbxepi(path_mov, bl_start + ev, bl_frames);
            epi = pipe.io.read_sbxepi(path_mov, epi_start + ev, epi_frames);
            
            bl = pipe.proc.averaget(pipe.reg.dft_and_apply(bl, target)); 
            epi = pipe.proc.averaget(pipe.reg.dft_and_apply(epi, target));  
            
            dff = (epi - bl)./bl;
            
            if isempty(images{i})
                images{i} = dff/length(events{i});
            else
                images{i} = images{i} + dff/length(events{i});
            end
            
            if isempty(mean_im)
                mean_im = epi/(length(events{i})*length(events));
            else
                mean_im = mean_im + epi/(length(events{i})*length(events));
            end
        end
        
        toc
    end
    
    %% Correct angle
    
    mean_im = mean_im';
    
    for i = 1:length(images)
        images{i} = images{i}';
    end
    
    %% Save variants
    
    mean_im = mean_im/max(max(mean_im));
    rectified = cell(1, 8);
    
    for i = 1:length(images)
        rectified{i} = images{i}/max(max(images{i}));
        rectified{i}(rectified{i} < 0) = 0;
    end
    
    rgb_horz(:, :, 1) = rectified{1}*0.75 + rectified{3}*0.25;
    rgb_horz(:, :, 2) = rectified{3}*0.50 + rectified{5}*0.5;
    rgb_horz(:, :, 3) = rectified{5}*0.25 + rectified{7}*0.75;
    
    rgb_vert(:, :, 1) = rectified{2}*0.75 + rectified{4}*0.25;
    rgb_vert(:, :, 2) = rectified{4}*0.50 + rectified{6}*0.5;
    rgb_vert(:, :, 3) = rectified{6}*0.25 + rectified{8}*0.75;
    
    rgb_mean = zeros(size(mean_im, 1), size(mean_im, 2), 3);
    for i = 1:3
        rgb_mean(:, :, i) = round(mean_im*255);
    end
    
    horz = zeros(size(mean_im, 1), size(mean_im, 2), n_bars);
    vert = zeros(size(mean_im, 1), size(mean_im, 2), n_bars);
    
    for i = 1:n_bars
        horz(:, :, i) = images{2*(i - 1) + 1};
        vert(:, :, i) = images{2*(i - 1) + 2};
    end
    
    [base, filename, ~] = fileparts(path_mov);
    pipe.io.write_tiff(horz, fullfile(base, [filename '-horizontal_bars_tb.tif']));
    pipe.io.write_tiff(vert, fullfile(base, [filename '-vertical_bars_lr.tif']));
    pipe.io.write_tiff(mean_im, fullfile(base, [filename '-mean_image.tif']));
    imwrite(round(rgb_horz*255), fullfile(base, [filename '-horizontal_bars_clr.jpg']))
    imwrite(round(rgb_vert*255), fullfile(base, [filename '-vertical_bars_clr.jpg']))
    imwrite(round(rgb_vert*255), fullfile(base, [filename '-mean_image.jpg']))
    
    disp(path_ml);
end

function cond = condition_number(ml, bar, horizontal)
% CONDITION_NUMBER Find the correct condition number for a bar
    cond = -1;

    if horizontal
        movie_name = sprintf('Mov(NoiseBarHorz%i,0,0)', bar);
    else
        movie_name = sprintf('Mov(NoiseBarVert%i,0,0)', bar);
    end
    
    for i = 1:length(ml.TaskObject)
        if strcmp(ml.TaskObject{i}, movie_name)
            cond = i;
        end
    end
end