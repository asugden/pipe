function evs = read_sbxevents(path)
%READ_SBXEVENTS Modified from scanbox sbx_get_ttlevents by Dario Ringach

    % Fix path if necessary
    [~, ~, ext] = fileparts(path);
    if isempty(ext)
        path = [path '.mj2_events'];
    elseif ~strcmp(ext, '.mj2_events')
        error('File not of correct .mj2_events type.');
    end

    % Check if file exists
    if ~exist(path, 'file')
        error(sprintf('File %s not found', path));
    end
    
    % Load data
    data = load(path, '-mat');
    
    % Correct using Dario's code
    if(~isempty(data.ttl_events))
        evs = data.ttl_events(:, 3)*256 + data.ttl_events(:, 2);
        % This fixes a bug in xevents...hopefully. This should really be
        % better checked.
        bad_idx = find(diff(evs) < 0);
        if ~isempty(bad_idx)
            if length(bad_idx) > 1
                error('xevents is messed up')
            end
            warndlg('xevents frames decreases, dropping before decrease.');
            evs = evs(bad_idx+1:end);
        end
        evs = evs';
    else
        evs = [];
    end
end

