function update_simpcells(mouse, varargin)
    
    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'dates', []);          % Defaults to running across all dates
    addOptional(p, 'server', []);         % Server name, empty if the same server
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
        re_pull = false;
        update_simpcell = false;
        
        for run = runs
            sc = pipe.load(mouse, date, run, 'simpcell', p.server, 'error', false);
            
            if ~isempty(sc)
                if ~isfield(sc, 'version') || sc.version < 2.0
                    update_simpcell = true;
                    
                    sigpath = pipe.path(mouse, date, run, 'signals', p.server);
                    file = dir(sigpath);
                    if datenum(file.date) > datenum(2017, 08, 01)  % Very conservative estimate- pip3 had not been written then
                        re_pull = true;
                        
                        if p.report_only
                            fprintf('Signals file from %s %6i %03i is out of date.\n', ...
                                mouse, date, run);
                        elseif re_pull
                            break;
                        end
                    elseif p.report_only
                        fprintf('Simpcell file from %s %6i %03i is out of date.\n', ...
                                mouse, date, run);
                    end
                end
            end
        end
        
        if re_pull && ~p.report_only
            pipe.postprocess(mouse, date, 'server', p.server, ...
                'force', true, 'job', true, 'raw', p.raw, 'f0', p.f0, ...
                'deconvolved', p.deconvolved, 'pupil', p.pupil, ...
                'brain_forces', p.brain_forces, 'photometry', p.photometry, ...
                'photometry_fiber', p.photometry_fiber);    
        elseif update_simpcell && ~p.report_only
            for run = runs
                pipe.io.write_simpcell(mouse, date, run, p.server, 'force', true);
            end
        end
    end
    
end