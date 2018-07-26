function mov = imread(path, k, N, pmt, optolevel, mtype)
% READ: read movie files. As of now can handle SBX. Will add TIF.

    % BEWARE: Corrected from 0-indexed to 1-indexed, both for k and pmt
    % Reads from frame k to k + (N - 1) in file fname
    % path  - the file path to .sbx file (e.g., 'xx0_000_001')
    % k     - the index of the first frame to be read.  The first index is 1.
    % N     - the number of consecutive frames to read starting with k.,
    % optional
    % pmt   - the number of the pmt, 1 for green or 2 for red, assumed to
    % be 1. If set to -1 and two PMTs exist, it will return both PMTs
    % optolevel - return a single optolevel instead of all. If passed an empty
    % array, it will return all z levels of optotune
    % mptype - force the movie type

    % Returns array of size = [rows cols N] 
    % If N<0 it returns an array to the end

    % Set to start at beginning if necessary
    if nargin < 2, k = 1; end
    % Set in to read the whole file if unset
    if nargin < 3 || N < 0, N = info.nframes - k; end
    % Automatically set the PMT to be green
    if nargin < 4, pmt = 1; end
    % Read a larger chunk if optotune was used
    if nargin < 5, optolevel = []; end
    if nargin < 6, mtype = []; end
    
    % Find file type
    [~, ~, ext] = fileparts(path);
    if strcmpi(mtype, 'sbx') || strcmpi(ext, '.sbx')
        mov = pipe.io.sbxRead(path, k, N, pmt, optolevel);
    else
        error('Cannot read movie type.');
    end
end

