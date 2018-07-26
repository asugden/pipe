function info = metadata(path, mtype)
% READ: read metadata for movie files. As of now can handle SBX.

    if nargin < 2, mtype = []; end
    
    % Find file type
    [~, ~, ext] = fileparts(path);
    if strcmpi(mtype, 'sbx') || strcmpi(ext, '.sbx')
        info = pipe.io.sbxInfo(path);
    else
        error('Cannot read metadata for movie type.');
    end
end

