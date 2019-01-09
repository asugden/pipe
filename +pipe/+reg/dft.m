function dft_transforms = dft(target_mov, varargin)
%SBXALIGNTURBOREGCORE aligns a file (given by path) using ImageJ's TurboReg
%   NOTE: hardcoded path to ImageJ.

    p = inputParser;
    addOptional(p, 'startframe', 1);  % The frame to start reading from if not xrun
    addOptional(p, 'nframes', 1);  % Number of frames to read if not xrun
    addOptional(p, 'mov_path', []);  % Path to an sbx movie to be read if not xrun
    addOptional(p, 'targetrefs', {});  % Cell array of target movs if xrun
    addOptional(p, 'xrun', false);  % Set to true if cross-run
    addOptional(p, 'binxy', 2);  % How much to bin in xy
    addOptional(p, 'pmt', 1, @isnumeric);  % 1-green, 2-red
    addOptional(p, 'optotune_level', []);  % Which optotune level to align
    addOptional(p, 'edges', [0, 0, 0, 0]);  % The edges to be removed
    addOptional(p, 'upsample', 100, @isnumeric);  % Advanced- do not change
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
        
    %% Get alignment data
    
    if p.xrun
        % Cross-run
        % Initialize output and read frames
        [x, y] = size(p.targetrefs{1});
        data = zeros(x, y, length(p.targetrefs));
        for tr = 1:length(p.targetrefs)
            data(:, :, tr) = p.targetrefs;
        end
    else
        % Within run
        data = pipe.imread(p.mov_path, p.startframe, p.nframes, p.pmt, ...
            p.optotune_level);
            
        % Get the standard edge removal and bin by 2
        data = data(p.edges(3)+1:end-p.edges(4), p.edges(1)+1:end-p.edges(2), :);
        data = pipe.proc.binxy(data, p.binxy);
    end
    
    %% Shared between xrun and within run
    % Get the sizes of the files
    dft_transforms = zeros(size(data, 3), 4);

    % Match the binning of the target to the data
    target_mov_binned = pipe.proc.binxy(target_mov, p.binxy);
    target_fft = fft2(double(target_mov_binned));
    % Iterate over all times
    for i = 1:size(data, 3)
        data_fft = fft2(double(data(:, :, i)));
        dft_transforms(i, :) =  pipe.reg.dftcore(target_fft, data_fft, p.upsample);
    end
end

