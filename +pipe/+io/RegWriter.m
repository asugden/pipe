classdef RegWriter
% A class to write SBX files, which keeps track of the current position
    properties
        path = [];
        curframe = 1;
        fid = -1;
        info = [];
    end
    
    methods
        function obj = RegWriter(path, info, extension, force)
            % Path for saving and info for matching, force allows overwrite
            % Set the extension if not sbxreg
            
            if nargin < 3, extension = '.sbxreg'; end
            if nargin < 4, force = false; end
            
            if ~strcmp(extension(1), '.'), extension = ['.' extension]; end
            [base, name, ~] = fileparts(path);
            path = fullfile(base, [name extension]);
            
            if exist(path, 'file') && ~force
                error('Cannot overwrite an existing file unless forced.');
            end
            
            obj.info = info;
            obj.path = path;
        end
        
        function write(obj, data)
            % Write a chunk of data. Note that data must be of the correct
            % size to match the data passed via info
            % If data is 1-color, should be squeezed to
            %   [height, width] or [height, width, length]
            % If data is 2-color, should be squeed to 
            %   [2, height, width] or [2, height, width, length]
            
            data = squeeze(data);
            if obj.info.nchan == 1 && ismatrix(data)
                data = reshape(data, [1 size(data, 1) size(data, 2) 1]);
            elseif obj.info.nchan == 1 && ndims(data) == 3
                data = reshape(data, [1 size(data, 1) size(data, 2) size(data, 3)]);
            elseif obj.info.nchan == 2 && ndims(data) == 3
                data = reshape(data, [size(data, 1) size(data, 2) size(data, 3) 1]);
            end
            
            if ndims(data) == 4 && size(data, 1) == obj.info.nchan ...
                    && obj.info.sz(1) == size(data, 2) && obj.info.sz(2) == size(data, 3) ...
                    && size(data, 4) + obj.curframe <= obj.info.nframes
                
                if ~isa(data, 'uint16')
                    if min(data) < 0, warndlg('Data passes below 0'); end
                    if max(data) > intmax('uint16'), warndlg('Data passes above 65535'); end
                    data(data < 0) = 0;
                    data(data > intmax('uint16')) = intmax('uint16');
                    data = uint16(data);
                end
                
                obj.curframe = obj.curframe + size(data, 4);
                data = intmax('uint16') - permute(data, [1 3 2 4]);
                data = reshape(data, [numel(data) 1]);
                
                fid = fopen(obj.path, 'a');
                fwrite(fid, data, 'uint16');
                fclose(fid);
                
                return;
            end
            
            error('Data must match that declared in info file.');
        end
        
        function close(obj)
            % Close and save the file
            disp(obj.curframe);
            if isempty(obj.fid), error('No file to close.'); end
            if obj.curframe < obj.info.nframes, warndlg('Did not write enough frames'); end
            % fclose(obj.fid);
            
            % Note, add optional info writer
        end
        
        function delete(obj)
            % fclose(obj.fid);
        end
    end
end