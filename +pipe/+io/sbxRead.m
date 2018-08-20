function x = sbxRead(path, k, N, pmt, optolevel)
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

    % Returns array of size = [rows cols N] 
    % If N<0 it returns an array to the end

    % Force a reload of the global info variables. Without this, trouble arises
    info = pipe.io.sbxInfo(path, true);

    % Set to start at beginning if necessary
    if nargin < 2, k = 1; end
    % Set in to read the whole file if unset
    if nargin < 3 || N < 0, N = info.nframes - k; end
    % Automatically set the PMT to be green
    if nargin < 4, pmt = 1; end
    % Read a larger chunk if optotune was used
    if nargin < 5, optolevel = []; end
    % Make sure that we don't search beyond the end of the file
    if N > info.nframes - k, N = info.nframes - k; end
    % Check that optolevel isn't asking for something that doesn't exist
    if ~isempty(optolevel) && ~info.optotune_used
        error('Optotune was not used for this file.');
    end

    % Check if file can be opened
    if ~isfield(info, 'fid') || info.fid == 1
        error(['Cannot read file' path]);
    end
    
    % Correct to 0-indexing for k
    k = k - 1;
    
    if isempty(optolevel)
        try
            fseek(info.fid, k*info.nsamples, 'bof');
            x = fread(info.fid, info.nsamples/2*N, 'uint16=>uint16');
            x = reshape(x, [info.nchan info.sz(2) info.recordsPerBuffer N]);
        catch
            error('Cannot read frame. Index range likely outside of bounds.');
        end
    else
        optocycle = length(info.otwave);  % Length of the optotune cycle
        k = k*optocycle + (optolevel - 1);  % Set the actual beginning in the file
        if k > info.nframes
            x = [];
            return;
        end
        
        % Account for overrunning the number of frames
        if k + N*optocycle > info.nframes
            N = floor((info.nframes - k)/optocycle);
        end
        
        bufwidth = info.nchan*info.sz(2)*info.recordsPerBuffer;
        x = zeros(1, bufwidth*N, 'uint16');
        for n = 0:N - 1
            fseek(info.fid, (k + n*optocycle)*info.nsamples, 'bof');
            x(n*bufwidth+1:(n + 1)*bufwidth) = fread(info.fid, info.nsamples/2, 'uint16=>uint16');
        end
        
        x = reshape(x, [info.nchan info.sz(2) info.recordsPerBuffer N]);
    end

    x = intmax('uint16') - permute(x, [1 3 2 4]);

    % Correct the output to a single PMT
    if info.nchan == 1
        if N > 1
            x = squeeze(x(1, :, :, :));
        else
            x = squeeze(x(1, :, :)); 
        end
    elseif pmt > -1
        if N > 1
            x = squeeze(x(pmt, :, :, :));
        else
            x = squeeze(x(pmt, :, :));
        end
    end
end