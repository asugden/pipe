function stimulus_tiff(mouse, date, run, pmt, server, fast)
%SBXSTIMULUSDFF Generates the mean stim dff for mouse date run

    if nargin < 4 || isempty(pmt), pmt = 1; end
    if nargin < 5, server = []; end
    if nargin < 6, fast = false; end

    % Set time ins econds before and after stim
    prestim = 1;
    poststim = 2;

    % Get the onset times
    ons = pipe.io.sbxOnsets(mouse, date, run, server);
    if isfield(ons, 'onsets') < 1, return; end
    
    % Load in the movies
    path = pipe.path(mouse, date, run, 'sbx', 'server', server);
    
    info = pipe.metadata(path);
    fr = info.framerate;
    preframes = ceil(prestim*fr);
    postframes = ceil(poststim*fr);
    
    fields = fieldnames(ons.codes);
    for i = 1:length(fields)
        nons = double(ons.onsets(ons.condition(1:length(ons.onsets)) == getfield(ons.codes, fields{i}))');
        if ~isempty(nons)
            spath = sprintf('%s_mean-dff-%s-across-%i.tif', path(1:end-4), fields{i}, length(nons));

            if ~exist(spath)
                % Output arrays
                nim = zeros(info.sz(1), info.sz(2));

                for j = 1:length(nons)
                    denom = pipe.proc.averaget(pipe.imread(path, nons(j) - preframes - 1, preframes, pmt, [], 'register', fast));
                    num = pipe.proc.averaget(pipe.imread(path, nons(j), postframes, pmt, [], 'register', fast));
                    
                    if ~isempty(nim) && ~isempty(denom)
                        nim = nim + (num - denom)./denom./length(nons);
                    end
                end

                writetiff(nim, spath, 'double');
            end
        end
    end     
end

