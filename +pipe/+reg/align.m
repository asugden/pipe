function out = align(impaths, varargin) %mouse, date, runs, target, pmt, pars)
% SBXALIGNAFFINEDFT First applies an affine alignment, and then follows it
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
    addOptional(p, 'tbin', 1, @isnumeric);  % Number of seconds to average in time for the affine alignment. Set to 0 for affine every frame
    addOptional(p, 'highpass_sigma', 5, @isnumeric);  % Size of Gaussian blur to be subtracted from a downsampled version of your image, only if affine
    addOptional(p, 'save_title', '');  % Text to append to a file extension (for multiple alignments)
    addOptional(p, 'chunksize', 1000, @isnumeric);  % The size of a chunk for automation. Recommended to not change
    addOptional(p, 'binxytarget', 2, @isnumeric);  % The number of pixels to downsample in space
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
    
    %% Save all target files, the last will be the main target
    
    xruntargetref = pipe.reg.target(targetpath, p.pmt, p.optotune_level, ...
            p.binxytarget, p.refoffset, p.refsize, p.edges);
        
    targetrefs = cell(1, length(impaths));
    for r = 1:length(impaths)
        targetrefs{r} = pipe.reg.target(impaths{r}, p.pmt, p.optotune_level, ...
            p.binxytarget, p.refoffset, p.refsize, p.edges);
    end

    bigref = pipe.reg.target(targetpath, p.pmt, p.optotune_level, 1, ...
        p.refoffset, p.refsize, p.edges);

    % Get the cross-run transforms to apply later
    xruntform = pipe.reg.turboreg(xruntargetref, 'xrun', true, ...
        'targetrefs', targetrefs, 'binxy', p.binxytarget, 'sigma', p.highpass_sigma, ...
        'aligntype', p.aligntype);

    %% Iterate over all runs
    for r = 1:length(impaths)
        % Get the path and info file
        path = impaths{r};
        info = sbxInfo(path);
        nframes = info.max_idx + 1;

        % Sort out how many frames to bin based on framerate
        if info.scanmode == 1
            % IF YOU ARE RESETTING THIS TO 1, STOP NOW!!!
            % Set the input parameter tbin to 0.
            % Please do not change variables in sbxAlignAffineDFT. Contact
            % Arthur first.
            binframes = max(1, round(15.49*p.tbin));
        else
            binframes = max(1, round(30.98*p.tbin));
        end

        % Affine align using turboreg in ImageJ
        runchunksize = floor(p.chunksize/binframes)*binframes*binframes;
        nchunks = ceil(nframes/runchunksize);
        ootform = cell(1, nchunks);
        for c = 1:nchunks
            if nchunks > 20, disp(sprintf('%Aligning %02i/%02i', c, nchunks)); end
            % ootform{c} = sbxAlignTurboRegCore(path, (c-1)*runchunksize+1,...
            %     runchunksize, targetpaths{r}, binframes, p.pmt, targetrefs{r}, p.edges, p.highpass_sigma);
            ootform{c} = sbxAlignTurboReg(targetpaths{r}, 'startframe', (c-1)*runchunksize+1, ...
                'nframes', runchunksize, 'mov_path', path, 'binframes', binframes, 'pmt', p.pmt, ...
                'edges', p.edges, 'sigma', p.highpass_sigma, 'aligntype', p.aligntype);
        end

        % Get the cross-run affine transform
        tform = cell(1, nframes);
        xtform = xruntform{r};

        % Put everything back in order and keep track of which indices
        % have values
        known = zeros(1, nframes);
        for c = 1:nchunks
            for f = 1:length(ootform{c})
                pos = (c - 1)*runchunksize + f;
                if pos <= nframes
                    tform{pos} = ootform{c}{f};
                    if ~isempty(tform{pos})
                        temp.T = xtform.T*tform{pos}.T;
                        temp.T(3, 1) = xtform.T(3, 1) + tform{pos}.T(3, 1);
                        temp.T(3, 2) = xtform.T(3, 2) + tform{pos}.T(3, 2);
                        tform{pos}.T = temp.T;
                        % tform{pos}.T = xtform.T*tform{pos}.T;
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
            tform = interpolateTransform(tform, known);

            % Affine align using turboreg in ImageJ
            nchunks = ceil(nframes/p.chunksize);
            ootform = cell(1, nchunks);
            ootrans = cell(1, nchunks);
            for c = 1:nchunks, ootform{c} = tform((c-1)*p.chunksize+1:min(nframes, c*p.chunksize)); end

            % Get the current parallel pool or initailize
            openParallel();

            parfor c = 1:nchunks
                ootrans{c} = sbxAlignAffinePlusDFT(path, (c-1)*p.chunksize+1, p.chunksize, bigref, ootform{c}, p.pmt, p.edges);
            end

            for c = 1:nchunks
                pos = (c - 1)*p.chunksize + 1;
                upos = min(c*p.chunksize, nframes);
                trans(pos:upos, :) = ootrans{c};
            end
        end

        afalign = [path(1:strfind(path,'.')-1) '.alignaffine' p.save_title];
        save(afalign, 'tform', 'trans', 'binframes');
    end
    out = 1;
end

