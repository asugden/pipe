function info = metadata(path, mtype_or_date, run, server, alternate_mtype)
% READ: read metadata for movie files. As of now can handle SBX.

    use_mdr = false;
    if nargin < 2
        mtype = []; 
    elseif nargin < 3
        mtype = mtype_or_date;
    elseif nargin < 4 
        server = [];
        mtype = [];
        use_mdr = true;
    elseif nargin < 5
        mtype = [];
        use_mdr = true;
    else
        mtype = alternate_mtype;
        use_mdr = true;
    end
    
    if use_mdr
        if isempty(mtype), mtype = 'sbx'; end
        path = pipe.path(path, mtype_or_date, run, mtype, server);
    end
    
    % Find file type
    [~, ~, ext] = fileparts(path);
    if strcmpi(mtype, 'sbx') || (length(ext) > 3 && strcmpi(ext(1:4), '.sbx'))
        info = pipe.io.read_sbxinfo(path);
    else
        error('Cannot read metadata for movie type.');
    end
end

