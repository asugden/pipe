function path = jobdb(server, priority, startup)
%JOBDB Path to the job database

    base = pipe.lab.pathbase(server);
        
    if strcmpi(priority, 'error')
        path = fullfile(base, 'jobdb', 'errorjobs');
    elseif strcmpi(priority, 'now')
        path = fullfile(base, 'jobdb', 'now');
    elseif strcmpi(priority, 'complete')
        path = fullfile(base, 'jobdb', 'completedjobs');
    elseif strcmp(priority, 'high')
        path = fullfile(base, 'jobdb', 'activejobs', 'priority_high');
    elseif strcmp(priority, 'high')
        path = fullfile(base, 'jobdb', 'activejobs', 'priority_high');
    else
        path = fullfile(base, 'jobdb', 'activejobs', 'priority_med');
    end
    
    if nargin == 3 && startup
        if ~exist(fullfile(base, 'jobdb'))
            mkdir(fullfile(base, 'jobdb'));
        end
        
        if ~exist(fullfile(base, 'jobdb', 'errorjobs'))
            mkdir(fullfile(base, 'jobdb', 'errorjobs'));
        end
        
        if ~exist(fullfile(base, 'jobdb', 'now'))
            mkdir(fullfile(base, 'jobdb', 'now'));
        end
        
        if ~exist(fullfile(base, 'jobdb', 'completedjobs'))
            mkdir(fullfile(base, 'jobdb', 'completedjobs'));
        end
        
        if ~exist(fullfile(base, 'jobdb', 'activejobs'))
            mkdir(fullfile(base, 'jobdb', 'activejobs'));
        end
        
        if ~exist(fullfile(base, 'jobdb', 'activejobs', 'priority_high'))
            mkdir(fullfile(base, 'jobdb', 'activejobs', 'priority_high'));
        end
        
        if ~exist(fullfile(base, 'jobdb', 'activejobs', 'priority_med'))
            mkdir(fullfile(base, 'jobdb', 'activejobs', 'priority_med'));
        end
        
        if ~exist(fullfile(base, 'jobdb', 'activejobs', 'priority_low'))
            mkdir(fullfile(base, 'jobdb', 'activejobs', 'priority_low'));
        end
    end
end

