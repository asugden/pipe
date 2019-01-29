function [remaining, path, server] = jobs_remaining()
%JOBS_REMAINING Get the number of jobs remaining across all servers

    remaining = 0;
    path = [];
    server = [];
    
    % First, get local files
    groups = {'low', 'med', 'high'};
    for g = 1:length(groups)
        jobs = localGetJobs(pipe.lab.jobdb([], groups{g}));
        remaining = remaining + length(jobs);
        if ~isempty(jobs), path = jobs{1}; end
    end
    if remaining > 0, return; end

    % If there's time, check the other servers in random order (so that no
    % one feels hurt)
    other_servers = {'megatron', 'atlas', 'santiago', 'beastmode', 'sweetness'};
    groups = {'med', 'high'};
    order = randperm(length(other_servers));
    
    for i = order
        for g = 1:length(groups)
            server_dir = pipe.lab.jobdb(other_servers{i}, groups{g});
            if ~exist(server_dir), break; end
            
            jobs = localGetJobs(server_dir);
            remaining = remaining + length(jobs);
            if ~isempty(jobs)
                path = jobs{1};
                server = other_servers{i};
            end
        end
        
        if remaining > 0, return; end
    end
end

function out = localGetJobs(path)
%localGetJobs Get the list of all jobs in a directory
    
    fs = dir(path);
    if length(fs) < 3
        out = [];
    else
        out = {};
        for i = 1:length(fs)
            if length(fs(i).name) > 4 && strcmp(fs(i).name(end-3:end), '.mat')
                out{end+1} = fullfile(path, fs(i).name);
            end
        end
    end
    
    out = sort(out);
end
