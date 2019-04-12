function deconvolved = deconvolve(mouse, date, run, server, force)
    if nargin < 4, server = []; end
    if nargin < 5, force = false; end

    decon_path = pipe.path(mouse, date, run, 'decon', server);
    sig_path = pipe.path(mouse, date, run, 'signals', server);

    if isempty(sig_path)
        error(sprintf('Signals file not found for %s %06i %03i', mouse, date, run));
    end

    file_sig = dir(sig_path);
    if ~isempty(decon_path)
        file_dec = dir(decon_path);
    end

    if isempty(decon_path) || force || datenum(file_dec.date) < datenum(file_sig.date)
        display('Deconvolving signals...')

        gd = pipe.load(mouse, date, run, 'signals', server);

        ncells = int16(length(gd.cellsort) - 1);
        nframes = int32(length(gd.cellsort(1).timecourse.dff_axon));

        dff = zeros(ncells, nframes);
        for i = 1:ncells
            dff(i, :) = gd.cellsort(i).timecourse.dff_axon;
        end

        deconvolved = pipe.proc.deconvolve(dff);
        dpath = pipe.path(mouse, date, run, 'decon', server, 'estimate', true);
        deconvolved = single(deconvolved);
        save(dpath, 'deconvolved');
    else
        decon = load(decon_path, '-mat');
        deconvolved = decon.deconvolved;
    end
    
    deconvolved = double(deconvolved);
end