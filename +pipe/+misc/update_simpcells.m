function update_simpcells(mouse, varargin)
    
    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'dates', []);          % Defaults to running across all dates
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
        
        if pipe.pull.is_clicked(mouse, date, runs, p.server)
            % Catch a bug in processing
            re_pull = false;

            for run = runs
                if ~p.ignore_signals
                    sigpath = pipe.path(mouse, date, run, 'signals', p.server);

                    if isempty(sigpath)
                        re_pull = true;
                    else
                        file = dir(sigpath);
                        if datenum(file.date) > datenum(2018, 08, 01)  % Very conservative estimate- pip3 had not been written then
                            sig = load(sigpath, '-mat');
                            if ~isfield(sig, 'updated_code') || sig.updated_code < 190401
                                re_pull = true;
                            end
                        end
                    end
                end

                if ~re_pull
                    re_simpcell = true;
                    sc = pipe.load(mouse, date, run, 'simpcell', p.server, 'error', false);

                    if ~isempty(sc)
                        if isfield(sc, 'version') && sc.version >= 2.0
                            re_simpcell = false;
                        end
                    end

                    if re_simpcell
                        fprintf('Simpcell file from %s %6i %03i is out of date.\n', ...
                            mouse, date, run);
                        if ~p.report_only
                            pipe.io.write_simpcell(mouse, date, run, ...
                                p.server, 'force', true);
                        end
                    end
                else
                    fprintf('Signals file from %s %6i is out of date.\n', ...
                                mouse, date);

                    if ~p.report_only
                        pipe.postprocess(mouse, date, 'server', p.server, ...
                            'force', true, 'job', true, 'raw', p.raw, 'f0', p.f0, ...
                            'deconvolved', p.deconvolved, 'pupil', p.pupil, ...
                            'brain_forces', p.brain_forces, 'photometry', p.photometry, ...
                            'photometry_fiber', p.photometry_fiber, 'save_tiff_checks', false);
                    end
                    break;
                end
            end
        end
    end
    
end