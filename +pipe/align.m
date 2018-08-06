function align(impaths, varargin) %mouse, date, runs, target, pmt, pars)
% PIPE.REG.ALIGN First applies an affine alignment, and then follows it
%   with a DFT registration if the affine alignment is averaged over frames
    % sbxpaths should be a cell array of paths to .sbx files

    p = inputParser;
    addOptional(p, 'aligntype', 'affine');  % Can be 'affine' or 'translation'
    addOptional(p, 'force', false);  % Allow overwriting if true
    addOptional(p, 'optotune_level', []);  % Align only a single optotune level if optotune is used
    addOptional(p, 'edges', []);  % Will be set from pipe.lab.badedges if empty
    addOptional(p, 'pmt', 1, @isnumeric);  % REMEMBER, PMT is 0-indexed
    addOptional(p, 'target', 1, @isnumeric);  % Which value to use as the target for cross-run alignment (index of runs)
    addOptional(p, 'refsize', 500, @isnumeric);  % The number of frames to average for the reference image
    addOptional(p, 'refoffset', 500, @isnumeric);  % How many frames from the onset should the reference be made
    addOptional(p, 'target_rounds', 3, @isnumeric);  % Number of DFT rounds to align target movie
    
    % Affine only
    addOptional(p, 'tbin', 1, @isnumeric);  % Number of seconds to average in time for the affine alignment. Set to 0 for affine every frame
    addOptional(p, 'binxy', 2, @isnumeric);  % The number of pixels to downsample in space
    addOptional(p, 'highpass_sigma', 5, @isnumeric);  % Size of Gaussian blur to be subtracted from a downsampled version of your image, only if affine
    addOptional(p, 'pre_register', false, @isboolean);  % If affine, pre-register with DFT if true
    addOptional(p, 'interpolation_type', 'spline');  % Used to be 'linear', changed to 'spline'
    
    % Extra options
    addOptional(p, 'save_title', '');  % Text to append to a file extension (for multiple alignments)
    addOptional(p, 'chunksize', 1000, @isnumeric);  % The size of a chunk for automation. Recommended to not change
    addOptional(p, 'verbose', false);  % Print out which stages are being processed on if true
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;

    if isempty(impaths), return; end
    if isempty(p.edges), p.edges = pipe.lab.badedges(impaths{1}); end
    
    % Will align to a reference taken from the first refsize frames of the
    % first run
    % Depends on hardcoded location of ImageJ
    
    %% Determine if output needs to be saved
    
    % Alignment extension
    alext = '.align';
    if strcmp(p.aligntype, 'affine')
        alext = [alext 'affine'];
    else
        alext = [alext 'xy'];
    end
    alext = [alext p.save_title];
    
    % Check if output must be saved
    saveoutput = zeros(1, length(impaths));
    for r = 1:length(impaths)
        % Check for alignment file
        path = impaths{r};
        alignfile = [path(1:strfind(path,'.')-1) alext];
        
        if ~exist(alignfile, 'file') || p.force
            saveoutput(r) = 1;
        elseif ~isempty(p.optotune_level)
            al = load(alignfile, '-mat');
            if isnan(al.trans(p.optotune_level, 3)) || isnan(al.trans(p.optotune_level, 4))
                saveoutput(r) = 1;
            end
        end
    end
    if sum(saveoutput) == 0, return; end
    
    % Restrict to only those paths that need alignment
    targetpath = impaths{p.target};
    newpaths = {};
    for i = 1:length(impaths)
        if saveoutput(i)
            newpaths{end+1} = impaths{i};
        end
    end
    impaths = newpaths;
    
    %% Create all run target files and align across runs
    
    % The dftref is not downsampled in space (and dft is not downsampled in
    % time)
    dftref = pipe.reg.target(targetpath, p.pmt, p.optotune_level, 1, ...
        p.refoffset, p.refsize, p.edges, p.target_rounds);
    
    if strcmp(p.aligntype, 'affine')
        % The cross-run target
        xruntargetref = pipe.reg.target(targetpath, p.pmt, p.optotune_level, ...
                p.binxy, p.refoffset, p.refsize, p.edges, p.target_rounds);

        % Targets for every individual run
        targetrefs = cell(1, length(impaths));
        xruntargetmatch = -1;
        for r = 1:length(impaths)
            if strcmp(impaths{r}, targetpath)
                targetrefs{r} = xruntargetref;
                xruntargetmatch = r;
            else
                targetrefs{r} = pipe.reg.target(impaths{r}, p.pmt, p.optotune_level, ...
                    p.binxy, p.refoffset, p.refsize, p.edges, p.target_rounds);
            end
        end

        % Get the cross-run transforms to apply later with no correction
        % required for the target movie
        xruntform = pipe.reg.turboreg(xruntargetref, 'xrun', true, ...
            'targetrefs', targetrefs, 'pmt', p.pmt, 'optotune_level', p.optotune_level, ...
            'binxy', p.binxy, 'sigma', p.highpass_sigma, ...
            'pre_register', p.pre_register);
        if xruntargetmatch > 0, xruntform{xruntargetmatch} = affine2d; end
    end

    %% Iterate over all runs
    for r = 1:length(impaths)
        % Get the path and info file
        path = impaths{r};
        alignfile = [path(1:strfind(path,'.')-1) alext];
        info = pipe.metadata(path);
        nframes = info.nframes;
        if info.optotune_used && ~isempty(p.optotune_level)
            nframes = floor(nframes/length(info.otwave));
        end 
        binframes = max(1, round(info.framerate*p.tbin));
        
        if strcmp(p.aligntype, 'affine')
            %% Affine alignment within a run
            
            % Affine align using turboreg in ImageJ
            runchunksize = floor(p.chunksize/binframes)*binframes*binframes;
            nchunks = ceil(nframes/runchunksize);
            ootform = cell(1, nchunks);
            for c = 1:nchunks
                if p.verbose, fprintf('%Aligning %02i/%02i', c, nchunks); end
                ootform{c} = pipe.reg.turboreg(targetrefs{r}, 'startframe', (c-1)*runchunksize+1, ...
                    'nframes', runchunksize, 'mov_path', path, 'binframes', ...
                    binframes, 'pmt', p.pmt, 'edges', p.edges, ...
                    'optotune_level', p.optotune_level, ...
                    'sigma', p.highpass_sigma, 'pre_register', p.pre_register);
            end

            % Get the cross-run affine transform
            tform = cell(1, nframes);
            xtform = xruntform{r};

            % Put everything back in order and keep track of which indices
            % have values
            known = zeros(1, nframes);
            for c = 1:nchunks
                for f = 1:length(ootform{c})
                    pos = round((c - 0.5)*runchunksize) + f;
                    if pos <= nframes
                        tform{pos} = ootform{c}{f};
                        if ~isempty(tform{pos})
                            temp.T = xtform.T*tform{pos}.T;
                            temp.T(3, 1) = xtform.T(3, 1) + tform{pos}.T(3, 1);
                            temp.T(3, 2) = xtform.T(3, 2) + tform{pos}.T(3, 2);
                            tform{pos}.T = temp.T;
                            known(pos) = 1; 
                        end
                    end
                end
            end
            indices = 1:nframes;
            indices(known < 1) = 0;
            known = indices(indices > 0);

            % Now fix interpolated registration with dft registration
            trans = zeros(nframes, 4);
            if binframes > 1
                % Interpolate any missing frames
                tform = interpolateTransform(tform, known, p.interpolation_type);

                % Affine align using turboreg in ImageJ
                nchunks = ceil(nframes/p.chunksize);
                ootform = cell(1, nchunks);
                ootrans = cell(1, nchunks);
                for c = 1:nchunks
                    ootform{c} = tform((c-1)*p.chunksize+1:min(nframes, c*p.chunksize)); 
                end

                % Get the current parallel pool or initailize
                pipe.parallel();
                parfor c = 1:nchunks
                    ootrans{c} = pipe.reg.postdft(path, (c-1)*p.chunksize+1, ...
                        p.chunksize, dftref, ootform{c}, p.pmt, ...
                        p.optotune_level, p.edges);
                end

                for c = 1:nchunks
                    pos = (c - 1)*p.chunksize + 1;
                    upos = min(c*p.chunksize, nframes);
                    trans(pos:upos, :) = ootrans{c};
                end
            end
            
            % And save, accounting for optotune levels
            if isempty(p.optotune_level) || ~info.optotune_used
                save(alignfile, 'tform', 'trans', 'binframes');
            else
                ltform = tform;
                ltrans = trans;
                if exist(alignfile, 'file')
                    aligndata = load(alignfile, '-mat');
                    trans = aligndata.trans;
                    tform = aligndata.tform;
                else
                    trans = zeros(info.nframes, 4);
                    trans(:, :) = nan;
                    tform = cell(info.nframes);
                end
                
                trans(p.optotune_level:length(info.otwave):info.nframes) = ltrans;
                tform(p.optotune_level:length(info.otwave):info.nframes) = ltform;
                save(alignfile, 'tform', 'trans', 'binframes');
            end
        else
            % DFT Alignment within a run
            
            trans = zeros(nframes, 4);
            nchunks = ceil(nframes/p.chunksize);
            ootrans = cell(1, nchunks);
            
            % Get the current parallel pool and register
            pipe.parallel();
            parfor c = 1:nchunks
                ootrans{c} = pipe.reg.dft(dftref, 'startframe', (c-1)*runchunksize+1, ...
                'nframes', runchunksize, 'mov_path', path, 'pmt', p.pmt, ...
                'edges', p.edges, 'optotune_level', p.optotune_level);
            end

            % Recombine to a vector
            for c = 1:nchunks
                pos = (c - 1)*p.chunksize + 1;
                upos = min(c*p.chunksize, nframes);
                trans(pos:upos, :) = ootrans{c};
            end
            
            % And save, accounting for optotune levels
            if isempty(p.optotune_level) || ~info.optotune_used
                save(alignfile, 'trans');
            else
                if exist(alignfile, 'file')
                    aligndata = load(alignfile, '-mat');
                    fulltrans = aligndata.trans;
                else
                    fulltrans = zeros(info.nframes, 4);
                    fulltrans(:, :) = nan;
                end
                
                fulltrans(p.optotune_level:length(info.otwave):info.nframes) = trans;
                trans = fulltrans;
                save(alignfile, 'trans');
            end
        end
    end
end

function tform = interpolateTransform(tform, known, itype)
% INTERPOLATETRANSFORM interpolates a transformation from known values

    if nargin < 3, itype = 'spline'; end  % can also be 'linear'

    % Throw out extremes if not linearly fitting
    if ~strcmp(itype, 'linear')
        % Extract values to throw out extremes
        vals = zeros(6, length(known));
        vals(:, :) = nan;
        for t = 1:length(known)
            if known(t) > -1 && isempty(tform{known(t)})
                known(t) = -1;
            elseif known(t) > -1
                for i = 1:3
                    for j = 1:2
                        vals((i-1)*3 + j, t) = tform{known(t)}.T(i, j);
                    end
                end
            end
        end

        % Throw out extremes
        mn = nanmean(vals, 2);
        stdev = nanstd(vals, [], 2);
        known(sum(vals > mn + 5*stdev, 1) > 0) = -1;
        known(sum(vals < mn - 5*stdev, 1) > 0) = -1;
    end
    
    if length(known) ~= length(tform), error('Known time length is wrong'); end
    
    % Fill in the end with the same values
    unknownpos = 1:length(known);
    knownpos = unknownpos(known > 0);
    unknownpos = unknownpos(known < 1);
    for i = knownpos(end):length(tform), tform{i} = tform{knownpos(end)}; end
    for i = 1:knownpos(1)-1, tform{i} = tform{knownpos(1)}; end
    unknownpos = unknownpos(unknownpos > knownpos(1));
    unknownpos = unknownpos(unknownpos < knownpos(end));
    
    % And interpolate
    for m = 1:3
        for n = 1:2
            vec = zeros(length(knownpos));
            for k = 1:length(knownpos), vec(k) = tform{knownpos(k)}.T(m, n); end
            unknownvec = interp1(knownpos, vec, unknownpos, itype);
            for k = 1:length(unknownpos), tform{unknownpos(k)}.T(m, n) = unknownvec(k); end
        end
    end
end