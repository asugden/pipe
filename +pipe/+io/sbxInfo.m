function nginfo = sbxInfo(path, force)
%get the global info variable
% WARNING: corrects the number of channels for .sbxreg and .sbxclean files

    % Declare both info_loaded and info as global variables
    global info_loaded info

    % Make sure we're opening the info .mat file
    [parent, fname, ext] = fileparts(path);
    regfind = strfind(fname, '_reg');
    regfind2 = strfind(fname, '_xyreg');
    if ~isempty(regfind), fname = fname(1:regfind-1); end
    if ~isempty(regfind2), fname = fname(1:regfind2-1); end
    if ~isempty(parent), parent = [parent '\']; end
    base = [parent fname];
    ipath = [base '.mat'];
    if isempty(ext), path = [path '.sbx']; end

    % Force reopening info if loading a file
    if nargin == 2 && force
        if(~isempty(info_loaded))   % Close previous info file
            try
                fclose(info.fid);
            catch
            end
            info_loaded = [];
        end
    end
    
    % Check if info is already loaded...
    if(isempty(info_loaded) || ~strcmp(base, info_loaded))
        if(~isempty(info_loaded))   % Close previous info file
            try
                fclose(info.fid);
            catch
            end
        end

        % Load the .mat info file
        load(ipath);

        % Add an alignment line if possible
        if(exist([base, '.align']))
            info.aligned = load([base, '.align'], '-mat');
        else
            info.aligned = [];
        end   

        % Account for the fact that we split channels for sbxreg files
        if strcmp(ext, '.sbxreg') || strcmp(ext, '.sbxclean') || strcmp(ext, '.sbxregclean')
            info.nchan = 1;
            info.channels = 2;
        end
        
        % Save the name of the loaded info file
        info_loaded = base;

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
                info.nchan = 2;      % both PMT0 & 1
                factor = 1;
            case 2
                info.nchan = 1;      % PMT 0
                factor = 2;
            case 3
                info.nchan = 1;      % PMT 1
                factor = 2;
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
        if isfield(info, 'volscan') && info.volscan > 0, info.optotune_used = true; end
        if ~isfield(info, 'volscan') && ~isempty(info.otwave), info.optotune_used = true; end
        
        info.framerate = 15.49;
        if info.scanmode == 0
            info.framerate = 30.98;
        end
    end
    
    nginfo = info;
end

