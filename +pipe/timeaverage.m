function timeaverage(mouse, date, run, varargin)
%TIMEAVERAGE Calculate and save a time average image.
    
    p = inputParser;
    addOptional(p, 'server', []);  % Add in the server name as a string
    addOptional(p, 'force', false);  % Force overwrite.
    addOptional(p, 'pmt', 1);  % The channel to average.
    addOptional(p, 'raw', false);  % Use raw data.
    addOptional(p, 'job', true);  % Set to true to run as a job, set to false to run immediately.
    addOptional(p, 'priority', 'med');  % Set the priority to be low, medium, or high.
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    %% Run each run individually if needed
    if nargin < 3 || isempty(run)
        runs = pipe.lab.runs(mouse, date, p.server);
        for i=1:length(runs)
            pipe.timeaverage(mouse, date, runs(i), varargin);
        end
        return
    end
    
    %% Save job if necessary
    if p.job
        % Convert parameters to struct
        pars = {};
        fns = fieldnames(p);
        for i = 1:length(fns)
            if ~strcmp(fns{i}, 'priority') && ~strcmp(fns{i}, 'job')
                pars{end + 1} = fns{i};
                pars{end + 1} = getfield(p, fns{i});
            end
        end
        
        pars{end + 1} = 'job';
        pars{end + 1} = false;

        % And save
        job_path = pipe.lab.jobdb([], p.priority);
        job = 'timeaverage';
        time = pipe.misc.timestamp();
        user = getenv('username');
        extra = '';
        if ~isempty(mouse)
            extra = [extra '_' mouse];
        end
        if ~isempty(date)
            extra = [extra '_' num2str(date)];
        end
        if ~isempty(run)
            extra = [extra '_' num2str(run)];
        end

        save(sprintf('%s\\%s_%s_%s%s.mat', job_path, ...
            pipe.misc.timestamp(), user, job, extra), 'mouse', 'date', 'run', 'job', ...
            'time', 'user', 'pars');
        disp('Time average sent to job system.');
        return;
    end
    
    %% Calculate time average
    sbx_path = pipe.lab.datapath(mouse, date, run, 'sbx', p.server);

    if p.raw, raw_str = 'raw'; else, raw_str = 'reg'; end
    save_path = sprintf('%s_pmt%i_%s_time_avg.png', ...
                        sbx_path(1:end-4), p.pmt, raw_str);

    if ~p.force && exist(save_path, 'file')
        return
    end
                    
    movie = pipe.imread(sbx_path, 1, [], p.pmt, [], 'register', ~p.raw);
    
    imwrite(uint16(mean(movie, 3)), save_path, 'png');
    
end

