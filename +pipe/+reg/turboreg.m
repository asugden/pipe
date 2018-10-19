function affine_transforms = turboreg(target_mov, varargin)
%SBXALIGNTURBOREGCORE aligns a file (given by path) using ImageJ's TurboReg
%   NOTE: hardcoded path to ImageJ.

    p = inputParser;
    addOptional(p, 'startframe', 1);  % The frame to start reading from if not xrun
    addOptional(p, 'nframes', 1);  % Number of frames to read if not xrun
    addOptional(p, 'mov_path', []);  % Path to an sbx movie to be read if not xrun
    addOptional(p, 'targetrefs', {});  % Cell array of target movs if xrun
    addOptional(p, 'xrun', false);  % Set to true if cross-run
    addOptional(p, 'binframes', 1);  % Bin frames in time
    addOptional(p, 'binxy', 2);  % How much to bin in xy
    addOptional(p, 'pmt', 1, @isnumeric);  % 1-green, 2-red
    addOptional(p, 'optotune_level', []);  % Which optotune level to align
    addOptional(p, 'pre_register', false);  % Transformation register with DFT first
    addOptional(p, 'edges', [0, 0, 0, 0]);  % The edges to be removed
    addOptional(p, 'sigma', 5);  % The sigma of a gaussian blur to be applied after downsampling
    addOptional(p, 'highpass', true);  % If true, subtract gaussian blur. Otherwise, skip
    % addOptional(p, 'aligntype', 'affine');  % Must be affine, but maybe
    % can be changed to allow rigid or other types
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    % Fix parameters
    if p.sigma <= 0, p.highpass = false; end    

    % Hardcoded path to ImageJ
    pipe.lab.runimagej();
    
    %% Get alignment data
    
    if p.xrun
        % Cross-run
        % Initialize output and read frames
        [x, y] = size(p.targetrefs{1});
        data = zeros(x, y, length(p.targetrefs));
        for tr = 1:length(p.targetrefs)
            data(:, :, tr) = p.targetrefs{tr};
        end
    else
        % Within run
        data = pipe.imread(p.mov_path, p.startframe, p.nframes, p.pmt, ...
            p.optotune_level);
            
        % Get the standard edge removal and bin by 2
        data = data(p.edges(3)+1:end-p.edges(4), p.edges(1)+1:end-p.edges(2), :);
        data = pipe.proc.binxy(data, p.binxy);

        % Bin if necessary
        if p.binframes > 1, data = pipe.proc.bint(data, p.binframes); end
    end
    
    % If desired, pre-align using dft to a target
    if p.pre_register
        dft_transforms = zeros(4, size(data, 3));
        upsample = 100;
        target_fft = fft2(double(target_mov));
        for i = 1:size(data, 3)
            data_fft = fft2(double(data(:, :, i)));
            [dft_transforms(:, i), reg] = ...
                pipe.reg.dftcore(target_fft, data_fft, upsample);
            data(:, :, i) = abs(ifft2(reg));
        end
    end
    
    %% Shared between xrun and within run
    % Get the sizes of the files
    affine_transforms = cell(1, size(data, 3));
    [y, x, ~] = size(data);
    
    % Subtract a blurred image if highpass is desired
    if p.highpass
        target_mov = target_mov - imgaussfilt(target_mov, p.sigma);
        data = data - imgaussfilt(data, p.sigma);
    end
    
    szstr = sprintf('0 0 %i %i ', x - 1, y - 1);
    % Estimate targets the way turboreg does
    targets = [0.5*x 0.15*y 0.5*x 0.15*y 0.15*x 0.85*y 0.15*x 0.85*y ...
        0.85*x 0.85*y 0.85*x 0.85*y];
    targets = round(targets);
    targetstr = sprintf('%i ', targets);
    
    % Create the text for the ImageJ macro
    alignstr = sprintf('-align -window data %s -window ref %s -affine %s -hideOutput', ...
        szstr, szstr, targetstr);
    
    % Run turboreg
    trhl = TurboRegHL_();
    ref = pipe.io.arrtoij(target_mov);
    src = pipe.io.arrtoij(data);
    trhl.runHL(ref, src, alignstr);
    tform = trhl.getAllSourcePoints();
    targetgeotransform = trhl.getTargetPoints();
    targetgeotransform = targetgeotransform(1:3, 1:2);

    % Iterate over all times
    for i = 1:length(affine_transforms)
        ftform = reshape(tform(i, :), 2, 3)';
        affine_transforms{i} = fitgeotrans(ftform, targetgeotransform, 'affine');
        affine_transforms{i}.T(3, 1) = affine_transforms{i}.T(3, 1)*p.binxy;
        affine_transforms{i}.T(3, 2) = affine_transforms{i}.T(3, 2)*p.binxy;
    end
    
    if p.pre_register
        warndlg('Double-check that rows are added to rows and columns to columns, not a mixup.');
        for i = 1:length(affine_transforms)
            affine_transforms{i}.T(3, 1) = (affine_transforms{i}.T(3, 1) + dft_transforms(3, i))*p.binxy;
            affine_transforms{i}.T(3, 2) = (affine_transforms{i}.T(3, 2) + dft_transforms(4, i))*p.binxy;
        end
    end
end

