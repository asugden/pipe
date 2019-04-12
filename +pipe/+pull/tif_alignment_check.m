function tif_alignment_check(mouse, date, runs, server)
    if nargin < 4, server = []; end
    if nargin < 3 || isempty(runs), runs = pipe.lab.runs(mouse, date, server); end
    
    sc_path = pipe.path(mouse, date, runs(1), 'simpcell', server);
    [save_path, ~, ~] = fileparts(sc_path);
    save_path = fullfile(save_path, 'first-last-500.tif');
    mov = [];
    
    for run = runs
        sbx_path = pipe.path(mouse, date, run, 'sbx', server);
        info = pipe.metadata(sbx_path);
        
        first = pipe.imread(sbx_path, 1, 500, 1, [], 'register', true);
        last = pipe.imread(sbx_path, info.nframes - 501, 500, 1, [], 'register', true);
        
        if isempty(mov)
            mov = first;
        else
            mov = cat(3, mov, first);
        end
        mov = cat(3, mov, last);
    end
    
    pipe.io.write_tiff(mov, save_path);
end