function save(path, varargin)
%SBXSAVEALIGNEDSBX Save an aligned copy of the sbx file so that future
%   reading and writing is dramatically sped up.

    p = inputParser;
    addOptional(p, 'extension', '.sbxreg');  % If adding extra title, requires '.' at beginning
    addOptional(p, 'chunksize', 1000, @isnumeric);  % Parfor chunking
    addOptional(p, 'force', false);  % Overwrite if true
    addOptional(p, 'registration_path', []);  % Estimated unless explicitly entered
    parse(p, varargin{:});
    p = p.Results;
    
    % Loop and save
    [base, name, ~] = fileparts(path);
    if exist(fullfile(base, [name p.extension]), 'file') && ~p.force
        return;
    end
    
    if isempty(p.registration_path)
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
    
    info = pipe.metadata(path);
    rw = pipe.io.RegWriter(path, info, p.extension, p.force);
    
    nchunks = ceil(info.nframes/p.chunksize);
    for c = 1:nchunks
        if info.nchan == 1
            data = pipe.imread(path, (c-1)*p.chunksize+1, p.chunksize, 1, [], ...
                'register', true, ...
                'registration_path', p.registration_path, ...
                'ignore_sbxreg', true);
        else
            data1 = pipe.imread(path, (c-1)*p.chunksize+1, p.chunksize, 1, [], ...
                'register', true, ...
                'registration_path', p.registration_path, ...
                'ignore_sbxreg', true);
            data = zeros(2, size(data1, 1), size(data1, 2), size(data1, 3));
            data(1, :, :, :) = data1;
            clear data1;
            data(2, :, :, :) = pipe.imread(path, (c-1)*p.chunksize+1, p.chunksize, 2, [], ...
                'register', true, ...
                'registration_path', p.registration_path, ...
                'ignore_sbxreg', true);
        end
        
        rw.write(data);
    end
    rw.close();
end