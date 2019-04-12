function cellsort = signals_core(path, fsz, nframes, cellsort, varargin)
%SBXPULLSIGNALSCORE Actually read in a chunked file and pull the signals
    p = inputParser;
    addOptional(p, 'pmt', 1);  % PMT to use for extraction
    addOptional(p, 'optolevel', []);  % optotune level to extract from
    addOptional(p, 'weighted_neuropil', false);  % Use non-binary neuropil mask
    addOptional(p, 'weighted_signal', false);  % Use non-binary signal mask
    addOptional(p, 'movie_type', []);
    addOptional(p, 'registration_path', []);
    addOptional(p, 'chunksize', 1000);  % Chunk size for parfor chunking
    parse(p, varargin{:});
    p = p.Results;

    % Get original file size and number of frames
    nrois = length(cellsort);
    nchunks = ceil(nframes/p.chunksize);
    csignal = cell(1, nchunks);
    cneuropil = cell(1, nchunks);
    
    openParallel();
    parfor c = 1:nchunks
        data = pipe.imread(path, ...
                           (c-1)*p.chunksize + 1, ...
                           p.chunksize, ...
                           p.pmt, ...
                           p.optolevel, ...
                           'register', true, ...
                           'mtype', p.movie_type, ...
                           'registration_path', p.registration_path);
        signals = zeros(size(data, 3), nrois);
        neuropil = zeros(size(data, 3), nrois - 1);
        
        if ~p.weighted_signal
            data = reshape(data, fsz(1)*fsz(2), size(data, 3));
        end
        
        for j = 1:nrois
            if ~p.weighted_signal
                signals(:, j) = mean(data(cellsort(j).mask(:), :));
            else
                for f = 1:size(data, 3)
                    signals(f, j) = cellsort(j).weights.*data(:, :, f);
                end
            end
            
            if j < nrois
                neuropil(:, j) = median(double(data(cellsort(j).neuropil == 1, :)));
            end
        end
        
        csignal{c} = signals;
        cneuropil{c} = neuropil;
    end
    
    signal = zeros(nframes, nrois);
    neuropil = zeros(nframes, nrois-1);
    for c = 1:nchunks
        lpos = (c - 1)*p.chunksize + 1;
        upos = min(c*p.chunksize, nframes);
        upos = min(upos, lpos + size(csignal{c}, 1) - 1);
        
        signal(lpos:upos, :) = csignal{c};
        neuropil(lpos:upos, :) = cneuropil{c};
    end

	% Neuropil subtraction
    signalsub = signal;
    signalsub(:, 1:end-1) = (signal(:, 1:end-1) - neuropil);
    median_sig = nanmedian(signal, 1);
    signalsub = bsxfun(@plus, signalsub, median_sig);

    % Now put into cellsort format
    for r = 1:nrois-1
        cellsort(r).timecourse.raw = signal(:, r)';
        cellsort(r).timecourse.neuropil = neuropil(:, r)';
        % try 
        if p.weighted_neuropil
            % Get weight to scale npil to maximize skewness of subtracted trace
            subfun = @(x) -1*skewness(cellsort(r).timecourse.raw - ...
                (x*cellsort(r).timecourse.neuropil));
            w = fminsearch(subfun, 1);
            w(w < 0) = 0; % can't be less than 0 or greater than 2
            w(w > 2) = 2;
            cellsort(r).timecourse.subtracted = (cellsort(r).timecourse.raw - ...
                (w.*cellsort(r).timecourse.neuropil)) + nanmedian(cellsort(r).timecourse.raw);
            cellsort(r).npil_weight = w;
        else
            cellsort(r).timecourse.subtracted = signalsub(:, r)';
            cellsort(r).npil_weight = 1;
        end
        % Jeff removed try/catch 190411
        % catch err
        %     cellsort(r).timecourse.subtracted = signalsub(:, r)';
        %     cellsort(r).npil_weight = 1;
        % end
    end
    
    cellsort(nrois).timecourse.raw = signal(:, nrois)';
    cellsort(nrois).timecourse.neuropil = zeros(1, size(signal, 1)); 
    cellsort(nrois).timecourse.subtracted = signal(:, nrois)';
    cellsort(nrois).npil_weight = 0;
end

