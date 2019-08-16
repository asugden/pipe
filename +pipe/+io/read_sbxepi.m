function data = read_sbxepi(path, k, N)
    % BEWARE: Corrected from 0-indexed to 1-indexed, both for k and pmt
    % Reads from frame k to k + (N - 1) in file fname
    % path  - the file path to .sbx file (e.g., 'xx0_000_001')
    % k     - the index of the first frame to be read.  The first index is 1.
    % N     - the number of consecutive frames to read starting with k.,
    % optional
    
    % Returns array of size = [rows cols N] 
    % If N<0 it returns an array to the end)

    if nargin < 2, k = 1; end
    if nargin < 3, N = -1; end
    
    % Fix path if necessary
    [~, ~, ext] = fileparts(path);
    if isempty(ext)
        path = [path '.mj2'];
    elseif ~strcmp(ext, '.mj2')
        error('File not of correct .mj2 type.');
    end

    % Check if file exists
    if ~exist(path, 'file')
        error(sprintf('File %s not found', path));
    end
    
    % Need to use global variables because of matlab memory leak
    global sbxepi_path sbxepi_videoreader;
    if ~strcmp(sbxepi_path, path)
        sbxepi_path = path;
        sbxepi_videoreader = VideoReader(sbxepi_path);
    end
    vr = sbxepi_videoreader;
        
    % Load data
    nframes = vr.Duration;
    if k < 1 || k > nframes
        error('Intial position k is out of bounds.');
    elseif (N < 1) || (k + (N - 1)) > nframes
        N = nframes - k + 1;
    end
    
    % Initialize data
    data = zeros(vr.Height, vr.Width, N);
    frames = k:k + (N - 1);
    
    % Read movie
    for j = 1:length(frames)
        vr.CurrentTime = frames(j);
        data(:, :, j) = readFrame(vr);
    end
end

