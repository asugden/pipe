function out = read_tiff(path, newType)
%READTIFF Reads TIFF file 

    if ~exist(path), error('Image file not found'); end
    if nargin < 2, newType = ''; end

    %% Get TIFF info
    
    [directory, name, ext] = fileparts(path);
    if directory(end) ~= '\' || directory(end) ~= '/', directory(end+1) = filesep; end

    td = ij.io.TiffDecoder(directory, [name ext]);
    tfi = td.getTiffInfo();
    fi = tfi(1);
    
    switch fi.fileType
        case fi.GRAY8
            dataType = 'uint8';
        case fi.GRAY16_UNSIGNED
            dataType = 'uint16';
        case fi.GRAY32_FLOAT
            dataType = 'single';
        case fi.GRAY32_UNSIGNED
            dataType = 'uint32';
        otherwise
            error('unknown tiff file type');
    end
    if isempty(newType); newType = dataType; end

    op = ij.io.Opener();
    imp = op.openTiffStack(tfi);
    out = pipe.io.ijtoarr(imp, newType);
end
