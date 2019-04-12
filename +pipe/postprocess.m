function postprocess(mouse, date, varargin)
%SBXPULLSIGNALS After an icamasks file has been created, pull signals and 
%   run simplifycellsort

    p = inputParser;
    addOptional(p, 'runs', []);  % A list of runs to use. If empty, use all runs
    addOptional(p, 'server', []);  % Server on which data resides
    addOptional(p, 'force', false);  % Overwrite files if they exist
    addOptional(p, 'job', false);  % Set to true to run as a job, set to false to run immediately.
    addOptional(p, 'priority', 'med');  % Set the priority to be low, medium, or high. Default is medium.
    
    addOptional(p, 'weighted_signal', false);  % Use weighting for signals rather than binary masks
    addOptional(p, 'weighted_neuropil', false);  % Use weighting for neuropil rather than binary masks
    addOptional(p, 'deconvolve', true);  % Save a deconvolved version of each of the traces
    addOptional(p, 'write_simpcell', true);  % Write a simpcell using defaults.
    addOptional(p, 'save_tiff_checks', true);  % Save TIFFs for checking data if true
    
    addOptional(p, 'pmt', 1);  % PMT to use for extraction
    addOptional(p, 'optotune_level', []);  % optotune level to extract from
    addOptional(p, 'movie_type', []);  % Set if using non-standard registration and want to use an alternate movie type such as .sbxreg
    addOptional(p, 'registration_path', []);  % Use a non-standard registration path
    addOptional(p, 'icapath', []);  % Path to ICA file, expected to be in the last run directory if empty
    addOptional(p, 'icarun', -1);  % ICA run number, required for looking for clicked cells
    addOptional(p, 'chunksize', 1000);  % Default chunk of frames for parallelization
    
    % SIMPCELL OPTIONS
    addOptional(p, 'raw', true);          % Include the raw data
    addOptional(p, 'f0', true);           % Include the running f0 baseline
    addOptional(p, 'deconvolved', true);  % Deconvolve and include deconvolved traces if true
    addOptional(p, 'pupil', false);       % Add pupil data-- turned off until improvements are made
    addOptional(p, 'brain_forces', false);% Add the motion of the brain as forces
    addOptional(p, 'photometry', false);  % Add photometry data
    addOptional(p, 'photometry_fiber', 1);% Which photometry fiber(s) to include, can be array    
    
    % Used by job system- do not set.
    addOptional(p, 'run_as_job', false);
    updated_code = 190412;
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    if nargin < 2, error('Date not set\n'); end
    if ~isempty(p.optotune_level), error('Not fully implemented yet.'); end
    
    %% Clean up the inputs

    if isempty(p.runs), p.runs = pipe.lab.runs(mouse, date, p.server); end
    if ~isnumeric(date), date = str2num(date); end
    
    % Prefer cellclicking, but fall back on icamasks
    % Also, will only work if ICA file exists
    if isempty(p.icapath)
        if p.icarun < 0, p.icarun = p.runs(end); end
        icapath = pipe.path(mouse, date, p.icarun, 'ica', p.server);
        if isempty(icapath)
            error('ICA not yet created for %s %d %02i. Try pipe.preprocess.', mouse, date, p.icarun);
        end
    else
        if p.icarun < 0
            error('ICA run number not set (p.icarun)');
        end
    end
    
     %% Save job if necessary
    
    if p.job && ~p.run_as_job
        % Convert parameters to struct
        pars = {};
        fns = fieldnames(p);
        for i = 1:length(fns)
            if ~strcmp(fns{i}, 'priority')
                pars{end + 1} = fns{i};
                pars{end + 1} = getfield(p, fns{i});
            end
        end

        % And save
        job_path = pipe.lab.jobdb([], p.priority);
        job = 'postprocess';
        time = timestamp();
        user = getenv('username');
        extra = '';
        if ~isempty(mouse)
            extra = [extra '_' mouse];
        end
        if ~isempty(date)
            extra = [extra '_' num2str(date)];
        end

        save(sprintf('%s\\%s_%s_%s%s.mat', job_path, ...
            timestamp(), user, job, extra), 'mouse', 'date', 'job', ...
            'time', 'user', 'pars');
        return;
    end
    
    %% Deal with old formats
    
    p.icapath = pipe.path(mouse, date, p.icarun, 'ica', p.server);
    
    p.legacy_clicking_format = false;
    [seld, erosions] = pipe.pull.clicked_from_server(mouse, date, p.icarun);
    if isempty(seld)
        icamaskspath = pipe.path(mouse, date, p.icarun, 'icamasks', p.server);
        if ~isempty(icamaskspath)
            disp('CellClick file not found. Using .icamasks instead.');
            p.legacy_clicking_format = true;
            load(icamaskspath, '-mat');
        else
            error('%s %d %02i not clicked yet.\n', mouse, date, p.icarun);
        end
    end
    
    %% Extract
    % New version using CellClick
    
    if ~p.legacy_clicking_format
        % Get image masks
        ica = load(p.icapath, '-mat');
        masks = cell(1, length(erosions));
        axons = false;
        if isfield(ica.icaguidata', 'pars') && isfield(ica.icaguidata.pars, 'axons')
            axons = ica.icaguidata.pars.axons;
        end
        
        for roi = 1:length(erosions)
            if (seld(roi))
                masks{roi} = pipe.extract.erosionmask(ica.icaguidata.ica(roi).filter, ...
                                                      erosions(roi), ~axons);
            end
        end
        
        for run = p.runs
            signals_path = pipe.path(mouse, date, run, 'signals', p.server, 'estimate', true);
            sbx_path = pipe.path(mouse, date, run, 'sbx', p.server, 'estimate', true);
            
            if ~exist(signals_path, 'file') || p.force
                fprintf('Pulling signals from %s\n', sbx_path);
                info = pipe.metadata(sbx_path);
               
                % Create cellsort output
                cellsort = struct();
                roiid = 1;
                for roi = 1:length(erosions)
                    if seld(roi)
                        cellsort(roiid).mask    = masks{roi};
                        cellsort(roiid).weights = ica.icaguidata.ica(roi).filter;
                        roiid = roiid + 1;
                    end
                end
                
                % Get edges for upsampling
                if isfield(ica.icaguidata', 'pars') && isfield(ica.icaguidata.pars, 'edges')
                    edges = ica.icaguidata.pars.edges;
                else
                    warndlg('WARNING: edges not found. Reverting to pipe.lab.badedges');
                    edges = pipe.lab.badedges(sbx_path);
                end
                
                % Get binning for upsampling
                if isfield(ica.icaguidata, 'pars')
                    binning = ica.icaguidata.pars.downsample_xy; %AL added 171116
                else
                    binning = 2;
                end
                
                % Upsample
                cellsort = pipe.pull.upsample_masks(cellsort, info.sz, edges, binning);
                
                % Get the neuropil traces
                cellsort = pipe.pull.neuropil(cellsort);
                
                % Extract the traces, chunking if possible
                cellsort = pipe.pull.signals_core( ...
                    sbx_path, info.sz, info.nframes, cellsort, ...
                    'pmt', p.pmt, ...
                    'optolevel', p.optotune_level, ...
                    'weighted_neuropil', p.weighted_neuropil, ...
                    'weighted_signal', p.weighted_signal, ...
                    'movie_type', p.movie_type, ...
                    'registration_path', p.registration_path, ...
                    'chunksize', p.chunksize);
                
                % Remove those ROI with signal in neuropil that matches signal in ROI
                cellsort = pipe.pull.neuropil_correlation(cellsort);

                % Get median-subtracted DFF Traces
                cellsort = pipe.pull.windowed_dff(cellsort, info.framerate);
                
                % Save signals in DFF values
                preprocess_pars = ica.icaguidata.pars;
                postprocess_pars = p;
                
                save(signals_path, 'cellsort', 'preprocess_pars', 'postprocess_pars', ...
                    'updated_code', '-v7.3');
            end
        end
    end
    
    %% Extract LEGACY
    % Former version using ICA masks
    
    if p.legacy_clicking_format
        for run = p.runs
            % Check if signals file already exists
            signals_path = pipe.path(mouse, date, run, 'signals', p.server, 'estimate', true);
            sbx_path = pipe.path(mouse, date, run, 'sbx', p.server, 'estimate', true);
            
            if ~exist(signals_path, 'file') || p.force
                fprintf('Pulling signals from %s\n', sbx_path);
                info = pipe.metadata(sbx_path);
                
                cellsort = icaguidata.icaStructForMovie;
                cellsort = pipe.pull.legacy_signals_core(sbx_path, info.sz, info.nframes, ...
                                                         cellsort, pipe.lab.badedges(), ...
                                                         p.weighted_neuropil, p.chunksize);

                % Remove those ROI with signal in neuropil that matches signal in ROI
                cellsort = pipe.pull.neuropil_correlation(cellsort);

                % Get median-subtracted DFF Traces
                cellsort = pipe.pull.windowed_dff(cellsort, info.framerate);
                
                % Save signals in DFF values
                preprocess_pars = struct('legacy', true);
                postprocess_pars = p;
                
                save(signals_path, 'cellsort', 'preprocess_pars', 'postprocess_pars', ...
                    'updated_code', '-v7.3');
            end
        end
    end
    
    %% Convert
    
    if (p.deconvolve)
        for run = p.runs
            pipe.pull.deconvolve(mouse, date, run, p.server, p.force);
        end
    end
    
    if (p.write_simpcell)
        for run = p.runs
            pipe.io.write_simpcell(mouse, date, run, ...
                'server', p.server, ...
                'force', p.force, ...
                'raw', p.raw, ...
                'f0', p.f0, ...
                'deconvolved', p.deconvolved, ...
                'pupil', p.pupil, ...
                'brain_forces', p.brain_forces, ...
                'photometry', p.photometry, ...
                'photometry_fiber', p.photometry_fiber ...
            );
    
        end
    end
    
    if (p.save_tiff_checks)
        pipe.pull.tif_alignment_check(mouse, date, p.runs, p.server);
    end
end 

