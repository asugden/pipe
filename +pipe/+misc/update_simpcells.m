function update_simpcells(mouse, varargin)
    
    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'dates', []);          % Defaults to running across all dates
    addOptional(p, 'runs', []);           % Defaults to all runs in directory(ies)
    addOptional(p, 'server', []);         % Server name, empty if the same server
    addOptional(p, 'ignore_signals', false); % If true, do not update signals files (Andrew)
    addOptional(p, 'report_only', false); % Report, don't rerun, bad dates if true
    
    addOptional(p, 'raw', true);          % Include the raw data
    addOptional(p, 'f0', true);           % Include the running f0 baseline
    addOptional(p, 'deconvolved', true);  % Deconvolve and include deconvolved traces if true
    addOptional(p, 'pupil', false);       % Add pupil data-- turned off until improvements are made
    addOptional(p, 'brain_forces', false);% Add the motion of the brain as forces
    addOptional(p, 'photometry', false);  % Add photometry data
    addOptional(p, 'photometry_fiber', 1);% Which photometry fiber(s) to include, can be array
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    % Set the default values for mouse, date, and run
    if isempty(p.dates)
        p.dates = pipe.lab.dates(mouse, p.server);
    end
    
    %% Iterate over all runs, checking recency
    
    for date = p.dates
        runs = pipe.lab.runs(mouse, date, p.server);
        if ~isempty(p.runs)
            runs = intersect(runs, p.runs);
        end

        if pipe.pull.is_clicked(mouse, date, runs, p.server)
            %
            % Catch a bug in processing
            %
            re_pull = false;
            for run = runs
                if ~p.ignore_signals
                    sigpath = pipe.path(mouse, date, run, 'signals', p.server);

                    if isempty(sigpath)
                        fprintf('Signals file missing, re-pulling: %s %6i\n', ...
                                mouse, date);
                        re_pull = true;
                        postprocess(mouse, date, p);
                        break
                    else
                        file = dir(sigpath);
                        if datenum(file.date) > datenum(2018, 08, 01)  % Very conservative estimate- pipe had not been written then
                            sig = load(sigpath, '-mat');
                            if ~isfield(sig, 'updated_code') || sig.updated_code < 190401
                                fprintf('Signals file from %s %6i is out of date.\n', ...
                                    mouse, date);
                                re_pull = true;
                                postprocess(mouse, date, p);
                                break
                            end
                        end
                    end
                end
            end
            if re_pull && ~p.report_only
                fprintf('Signals pull in progress, re-run later for remaining checks: %s %6i\n', ...
                    mouse, date);
                continue
            end
            %
            % Check modification times and simpcells
            %
            re_simpcell = false;
            for run = runs
                sig_path = pipe.path(mouse, date, run, 'signals', p.server);
                if isempty(sig_path)
                    sig_dir = [];
                else
                    sig_dir = dir(sig_path);
                end
                decon_path = pipe.path(mouse, date, run, 'decon', p.server);
                if isempty(decon_path)
                    decon_dir = [];
                else
                    decon_dir = dir(decon_path);
                end
                simp_path = pipe.path(mouse, date, run, 'simpcell', p.server);
                if isempty(simp_path)
                    simp_dir = [];
                else
                    simp_dir = dir(simp_path);
                end
                
                if isempty(sig_dir) || isempty(decon_dir) || isempty(simp_dir) || ...
                        datenum(sig_dir.date) > datenum(decon_dir.date) || ...
                        datenum(decon_dir.date) > datenum(simp_dir.date)
                    % Pulling decon for simpcell automatically checks
                    % update dates, so will also re-run decon if needed.
                    fprintf('Simpcell file from %s %6i %03i is out of date.\n', ...
                            mouse, date, run);
                    re_simpcell = true;
                    simpcell(mouse, date, p);
                else
                    sc = pipe.load(mouse, date, run, 'simpcell', p.server, 'error', false);
                    if ~isfield(sc, 'version') || sc.version < 2.0
                        fprintf('Simpcell file from %s %6i %03i is old.\n', ...
                            mouse, date, run);
                        re_simpcell = true;
                        simpcell(mouse, date, p);
                    end
                end
            end
            if re_simpcell && ~p.report_only
                fprintf('Simpcell re-write in progress, re-run later for remaining checks: %s %6i\n', ...
                    mouse, date);
                continue
            end
        end
    end
    
end


function postprocess(mouse, date, p)
    if ~p.report_only
        pipe.postprocess(mouse, date, 'server', p.server, ...
            'force', true, 'job', true, 'raw', p.raw, 'f0', p.f0, ...
            'deconvolved', p.deconvolved, 'pupil', p.pupil, ...
            'brain_forces', p.brain_forces, 'photometry', p.photometry, ...
            'photometry_fiber', p.photometry_fiber, 'save_tiff_checks', false);
    end
end


function simpcell(mouse, date, p)
    if ~p.report_only
        pipe.io.write_simpcell(mouse, date, run, ...
            'server', p.server, 'force', true, ...
            'raw', p.raw, 'f0', p.f0, ...
            'deconvolved', p.deconvolved, 'pupil', p.pupil, ...
            'brain_forces', p.brain_forces, 'photometry', p.photometry, ...
            'photometry_fiber', p.photometry_fiber);
    end
end
