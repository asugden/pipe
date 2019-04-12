function jobmaster(varargin)
%JOBS Run all jobs that have been added with sbxJob

    % Parameters for script
    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'quiet_hours', [8 18]);  % Can be set to [8 18] to turn off during the day (weekdays only)
    addOptional(p, 'check_every_min', 5);  % Check for new jobs every 5 minutes
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    %% Make sure that directories are made and reset
    
    % Get paths
    path_now = pipe.lab.jobdb([], 'now', true);
    % path_error = pipe.lab.jobdb([], 'error');
    % path_complete = pipe.lab.jobdb([], 'complete');
    path_high = pipe.lab.jobdb([], 'high');
    
    % Announce to the world that this user is running jobmaster
    user = getenv('username');
    if exist(fullfile(path_now, 'master.mat'), 'file')
        master = load(fullfile(path_now, 'master.mat'));
        
        if strcmp(master.user, user)
            delete(fullfile(path_now, 'master.mat'));
        else
            disp(sprintf(['Another user, %s, is already running the master. ' ...
                'It last checked in with %i remaining jobs at %s.'], master.user, ...
                master.remaining, master.time));
            return;
        end
    end
    
    % Return unfinished files to the queue
    fs = dir(path_now);    
    for i = 1:length(fs)
        if length(fs(i).name) > 4 && strcmp(fs(i).name(end-3:end), '.mat')
            fprintf('Moving file %s to high priority\n', fs(i).name);
            movefile(fullfile(path_now, fs(i).name), fullfile(path_high, fs(i).name));
        end
    end

    %% Iterate until control + c'ed
    
    while 1
        % Check in so that others know that the function is still running
        time = pipe.misc.timestamp();
        time_now = clock();
        [remaining, path, server] = pipe.lab.jobs_remaining();
        save(fullfile(path_now, 'master.mat'), 'user', 'time', 'remaining');
        
        if ~isempty(p.quiet_hours) && weekday(now) > 1 && weekday(now) < 7 ...
                && time_now(4) >= p.quiet_hours(1) && time_now(4) < p.quiet_hours(2)
            % If a weekday during quiet hours, wait.
            pause_hours = p.quiet_hours(2) - time_now(4);
            fprintf('Waiting %i hours until evening time\n', pause_hours);
            pause(pause_hours*60*60);
        elseif remaining > 0
            % Run first remaining file
            % Open the job and move it to the active directory
            job = load(path);
            [~, fname, ~] = fileparts(path);
            movefile(path, fullfile(path_now, [fname '.mat']));        
        
            tic;
            switch job.job
                case 'preprocess'
                    fprintf('\n\n\n\n-----\nPreprocessing file %s at %s\n', fname, pipe.misc.timestamp());
                    try 
                        job.pars = add_server(job.pars, server);
                        job.pars{end+1} = 'run_as_job';
                        job.pars{end+1} = true;
                        pipe.preprocess(job.mouse, job.date, job.pars);
                        path_complete = pipe.lab.jobdb(server, 'complete');
                        movefile(fullfile(path_now, [fname '.mat']), fullfile(path_complete, [fname '.mat']));
                    catch err
                        path_error = pipe.lab.jobdb(server, 'error');
                        movefile(fullfile(path_now, [fname '.mat']), fullfile(path_error, [fname '.mat']));
                        disp(['Error on job ' fname]);
                        
                        % Write error info to file
                        fid = fopen(fullfile(path_error, [fname '.log']), 'w+');
                        fprintf(fid, '%s', err.getReport('extended', 'hyperlinks', 'off'));
                        fclose(fid);
                    end
                case 'postprocess'
                    fprintf('\n\n\n\n-----\nPostprocessing file %s at %s\n', fname, pipe.misc.timestamp());
                    try 
                        job.pars = add_server(job.pars, server);
                        job.pars{end+1} = 'run_as_job';
                        job.pars{end+1} = true;
                        pipe.postprocess(job.mouse, job.date, job.pars);
                        path_complete = pipe.lab.jobdb(server, 'complete');
                        movefile(fullfile(path_now, [fname '.mat']), fullfile(path_complete, [fname '.mat']));
                    catch err
                        path_error = pipe.lab.jobdb(server, 'error');
                        movefile(fullfile(path_now, [fname '.mat']), fullfile(path_error, [fname '.mat']));
                        disp(['Error on job ' fname]);
                        
                        % Write error info to file
                        fid = fopen(fullfile(path_error, [fname '.log']), 'w+');
                        fprintf(fid, '%s', err.getReport('extended', 'hyperlinks', 'off'));
                        fclose(fid);
                    end
            end
            joblength = toc;
            fprintf('The job took %f minutes\n', joblength/60);
            close all;
        else
            % Pause until the next check
            pause(60*p.check_every_min);
        end
    end
end

function pars = add_server(pars, server)
    % Add the server name to a cell array of parameters
    
    found = false;
    for i = 0:length(pars)/2 - 1
        if strcmp(pars{2*i + 1}, 'server')
            if isempty(pars{2*i + 2})
                pars{2*i + 2} = server;
            end
            found = true;
        end
    end
    
    if ~found
        job.pars{end+1} = 'server';
        job.pars{end+1} = true;
    end
end