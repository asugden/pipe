function mov = imread(path, k, N, pmt, optolevel, varargin)
% READ: read movie files. As of now can handle SBX. Will add TIF.

    % BEWARE: Corrected from 0-indexed to 1-indexed, both for k and pmt
    % Reads from frame k to k + (N - 1) in file fname
    % path  - the file path to .sbx file (e.g., 'xx0_000_001')
    % k     - the index of the first frame to be read.  The first index is 1.
    % N     - the number of consecutive frames to read starting with k.,
    %   optional
    % pmt   - the number of the pmt, 1 for green or 2 for red, assumed to
    %   be 1. If set to -1 and two PMTs exist, it will return both PMTs
    % optolevel - return a single optolevel instead of all. If passed an empty
    % array, it will return all z levels of optotune
    % mptype - force the movie type

    % Returns array of size = [rows cols N] 
    % If N<0 it returns an array to the end

    % Set to start at beginning if necessary
    if nargin < 2, k = 1; end
    if k == 0, error('imread is 1-indexed, first frame must be >0'); end
    % Set in to read the whole file if unset
    if nargin < 3 || isempty(N) || N < 0, N = -1; end
    % Automatically set the PMT to be green
    if nargin < 4, pmt = 1; end
    % Read a larger chunk if optotune was used
    if nargin < 5, optolevel = []; end
    
    p = inputParser;
    addOptional(p, 'mtype', []);  % Movie type- estimated from extension unless entered here
    addOptional(p, 'register', false);  % Register upon reading if true
    addOptional(p, 'registration_path', []);  % Estimated unless explicitly entered
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    %% Deal with registration
    
    % Find file type
    [~, ~, ext] = fileparts(path);
    if p.register && (~strcmpi(ext, '.sbxreg') || ~isempty(p.registration_path))
        if isempty(p.registration_path)
            [base, name, ~] = fileparts(path);
            % Catch existing sbxreg files
            if exist(fullfile(base, [name '.sbxreg']), 'file')
                mov = pipe.imread(fullfile(base, [name '.sbxreg']), k, N, pmt, optolevel);
                return;
            end
            
            % Look for affine alignment, then dft alignment for realtime
            if exist(fullfile(base, [name '.alignaffine']), 'file')
                p.registration_path = fullfile(base, [name '.alignaffine']);
            elseif exist(fullfile(base, [name '.alignxy']), 'file')
                p.registration_path = fullfile(base, [name '.alignxy']);
            end
        end
        % Catch missing registration files
        if isempty(p.registration_path) || ~exist(p.registration_path, 'file')
            error('Registration file not found.'); 
        end
        
        % Return aligned file
        mov = pipe.reg.aligned(path, p.registration_path, k, N, pmt, optolevel);
        return;
    end
    
    %% Read file
    
    if strcmpi(p.mtype, 'sbx') || (length(ext) > 3 && strcmpi(ext(1:4), '.sbx'))
        mov = pipe.io.read_sbx(path, k, N, pmt, optolevel);
    else
        error('Cannot read movie type.');
    end
end

