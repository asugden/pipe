function zs = optoz(path, varargin)
%OPTOZ Return and save the optimal z levels for each time point

    p = inputParser;
    addOptional(p, 'startframe', 500);  % The frame to start reading from if not xrun
    addOptional(p, 'n_refstacks', 50);  % Number of stacks to combine for the reference
    addOptional(p, 'binxy', 2);  % How much to bin in xy
    addOptional(p, 'pmt', 1, @isnumeric);  % 1-green, 2-red
    addOptional(p, 'chunksize', 1000, @isnumeric);  % Number of frames per chunk
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
        
    %% Make reference stack

    info = pipe.metadata(path);
    
    
    refmov = pipe.imread(path, p.startframe, p.n_refstacks*info.otlevels, p.pmt, []);
    refmov = reshape(refmov, [size(refmov, 1), size(refmov, 2), info.otlevels, p.n_refstacks]);

    ref = median(refmov, 4)
    
    
    zs = [];
    
    


end

