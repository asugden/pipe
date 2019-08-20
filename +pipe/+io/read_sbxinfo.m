function nginfo = read_sbxinfo(path, force)
%get the global info variable
% WARNING: corrects the number of channels for .sbxreg and .sbxclean files

    % Declare both info_loaded and info as global variables
    global pipe_info_loaded info

    % Make sure we're opening the info .mat file
    [parent, fname, ext] = fileparts(path);
    
    % LEGACY
    % An annoying bit of legacy code, catch the fact that we used to split
    % channels in registered files
    splitchan = false;
    if strcmp(ext, '.sbxreg') || strcmp(ext, '.sbxclean') || strcmp(ext, '.sbxregclean')
        regfind = strfind(fname, '_reg');
        regfind2 = strfind(fname, '_xyreg');
        if ~isempty(regfind)
            fname = fname(1:regfind-1); 
            splitchan = true;
        elseif ~isempty(regfind2)
            fname = fname(1:regfind2-1); 
            splitchan = true;
        end
    end
    
    % Find the name of the info file
    if ~isempty(parent), parent = [parent '\']; end
    base = [parent fname];
    ipath = [base '.mat'];
    if isempty(ext), path = [path '.sbx']; end

    % Force reopening info if loading a file
    if nargin == 2 && force
        if(~isempty(pipe_info_loaded))   % Close previous info file
            try
                fclose(info.fid);
            catch
            end
            pipe_info_loaded = [];
        end
    end
    
    % Check if info is already loaded...
    if(isempty(pipe_info_loaded) || ~strcmp(base, pipe_info_loaded))
        if(~isempty(pipe_info_loaded))   % Close previous info file
            try
                fclose(info.fid);
            catch
            end
        end
        % Clear this for now, will set correctly later if everything worked
        pipe_info_loaded = [];

        % Load the .mat info file
        load(ipath);

        % LEGACY
        % Account for the fact that we split channels for sbxreg files
        if splitchan
            info.nchan = 1;
            info.channels = 2;
        end

        % Fix mistakes from previous scanbox versions
        if(~isfield(info,'sz'))
            sz = [512 796];
        end

        % Add a fix for bidirectional scanning
        if(info.scanmode == 0)
            % If bidirectional scanning, double the records per buffer
            info.recordsPerBuffer = info.recordsPerBuffer*2;
        end

        % channels is always set to 2, so it's completely useless. Instead,
        % use PMT gain
        switch info.channels
            case 1
                info.nchan = 2;      % both PMT 0 & 1
                info.pmts = [1 2];
                factor = 1;
            case 2
                info.nchan = 1;      % PMT 0
                info.pmts = 1;
                factor = 2;
            case 3
                info.nchan = 1;      % PMT 1
                info.pmts = 2;
                factor = 2;
            case -1  % For version 3 scanbox info file
                assert(nnz(info.chan.save) == info.chan.nchan);
                info.nchan = info.chan.nchan;
                info.pmts = find(info.chan.save);
                if info.nchan == 2
                    factor = 1;
                elseif info.nchan == 1
                    factor = 2;
                else
                    error('Incomplete: Unknown how sbx files are written for >2 channels.');
                end
        end

        info.fid = fopen(path);
        d = dir(path);
        info.nsamples = (info.sz(2)*info.recordsPerBuffer*2*info.nchan);   % bytes per record 

        if isfield(info, 'scanbox_version') && info.scanbox_version >= 2
            info.max_idx = d.bytes/info.recordsPerBuffer/info.sz(2)*factor/4 - 1;
            info.nsamples = (info.sz(2)*info.recordsPerBuffer*2*info.nchan);   % bytes per record 
        else
            info.max_idx =  d.bytes/info.bytesPerBuffer*factor - 1;
        end
        
        % Appended useful information
        info.nframes = info.max_idx + 1;
        info.optotune_used = false;
        info.otlevels = 1;
        if isfield(info, 'volscan') && info.volscan > 0, info.optotune_used = true; end
        if ~isfield(info, 'volscan') && ~isempty(info.otwave), info.optotune_used = true; end
        if info.optotune_used, info.otlevels = length(info.otwave); end
        
        info.framerate = 15.49;
        if info.scanmode == 0
            info.framerate = 30.98;
        end
        
        info.height = info.sz(2);
        info.width = info.recordsPerBuffer;

        % Save the name of the loaded info file
        pipe_info_loaded = base;
    end
    
    nginfo = info;
end

