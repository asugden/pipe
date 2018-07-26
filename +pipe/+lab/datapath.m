function path = datapath(mouse, date, run, ftype, server, varargin)
%DATAPATH Returns the path to a data directory

    % Set unset arguments
    if isempty(mouse), error('Mouse name not set'); end
    if nargin < 2, date = []; end
    if nargin < 3, run = []; end
    if nargin < 4, ftype = []; end
    if nargin < 5, server = []; end

    % Parse optional inputs
    p = inputParser;
    addOptional(p, 'estimate', false);  % Whether to give an estimate of where the path would be if it does not exist
    addOptional(p, 'pmt', []);  % Which PMT, in the case of sbxreg and sbxclean
    parse(p, varargin{:});
    p = p.Results;
    
    % Make it so that it can iterate over runs or dates
    if ~isempty(date) && ~ischar(date) && length(date) > 1
        path = {};
        for d = 1:length(date)
            if iscell(date)
                path{end+1} = path.io.datapath(mouse, date{d}, run, ftype, server, p);
            else
                path{end+1} = path.io.datapath(mouse, date(d), run, ftype, server, p);
            end
        end
        return
    end
    
    if ~isempty(run) && length(run) > 1
        path = {};
        for r = run
            path{end+1} = path.io.datapath(mouse, date, r, ftype, server, p);
        end
        return
    end
    
    % Prepare output
    if isempty(date)
        path = pipe.lab.mousedir(mouse, server);
    elseif isempty(run)
        path = pipe.lab.datedir(mouse, date, server);
    else
        path = pipe.lab.rundir(mouse, date, run, server);
    end
    
    % Get file type if desired, or return path
    if isempty(ftype) || isempty(path)
        return
    end
    
    % Get path
    if ~isempty(date) && isnumeric(date)
        date = sprintf('%6i', date);
    end
        
    sbxpath = extensionsearch(path, 'sbx');
    if ~isempty(sbxpath)
        [~, sbxname, ~] = fileparts(sbxpath);
    elseif isempty(date)
        sbxname = mouse;
    elseif isempty(run) 
        sbxname = sprintf('%s_%s', mouse, date);
    else
        sbxname = sprintf('%s_%s_%03i', mouse, date, run);
    end
    
    switch ftype
        case 'sbx'
            path = sbxpath;
        case 'clean'
            path = fullfile(path, [sbxname '.sbxclean']);
        case 'info'
            path = fullfile(path, sbxpath(1:end - 4));
        case 'simpcell'
            fname = sprintf('%s_%s_%03i.simpcell', mouse, date, run);
            path = fullfile(pipe.lab.datedir(mouse, date, server), fname);
        case 'simpglm'
            fname = sprintf('%s_%s.simpglm', mouse, date);
            path = fullfile(pipe.lab.datedir(mouse, date, server), fname);
        case 'safeglm'
            fname = sprintf('%s_%s.safeglm', mouse, date);
            path = fullfile(pipe.lab.datedir(mouse, date, server), fname);
        case 'pupil'
            path = fullfile(path, [sbxname '_eye.mat']);
        case 'quad'
            path = fullfile(path, [sbxname '_quadrature.mat']);
            
%         case 'xyreg'
%             ftype = 'sbxreg';
%             fs = dir(searchdir);
%             for i=1:length(fs)
%                 [~, fname, ext] = fileparts(fs(i).name);
%                 if strcmp(ext, sprintf('.%s', ftype))
%                     if isempty(p.pmt) || ~isempty(strfind([fname ext], sprintf('_xyreg-%i.sbxreg', p.pmt)))
%                        path = sprintf('%s%s', searchdir, fs(i).name);
%                     end
%                 end
%             end
%         case 'demonsreg'
%             ftype = 'sbxreg';
%             fs = dir(searchdir);
%             for i=1:length(fs)
%                 [~, fname, ext] = fileparts(fs(i).name);
%                 if strcmp(ext, sprintf('.%s', ftype))
%                     if isempty(p.pmt) || ~isempty(strfind([fname ext], sprintf('_demonsreg-%i.sbxreg', p.pmt)))
%                         path = sprintf('%s%s', searchdir, fs(i).name);
%                     end
%                 end
%             end
%         case 'xyregclean'
%             ftype = 'sbxclean';
%             fs = dir(searchdir);
%             for i=1:length(fs)
%                 [~, fname, ext] = fileparts(fs(i).name);
%                 if strcmp(ext, sprintf('.%s', ftype))
%                     if isempty(p.pmt) || ~isempty(strfind(fname, sprintf('_xyreg-%i', p.pmt)))
%                         path = sprintf('%s%s', searchdir, fs(i).name);
%                     end
%                 end
%             end

        otherwise
            path = extensionsearch(path, ftype);
            % [fs, ~] = nestedSortStruct(fs, 'date'); %AL added 180322
    end
    
    if p.estimate && isempty(path)
        path = fullfile(path, [sbxname '.' ftype]);
    elseif ~p.estimate
        if ~exist(path, 'file')
            path = [];
        end
    end

end

function filename = extensionsearch(searchdir, ftype)
%EXTENSIONSEARCH search a directory for a particular extension, ext
    filename = [];
    fs = dir(searchdir);
    for i=1:length(fs)
        [~, ~, ext] = fileparts(fs(i).name);
        if strcmp(ext, sprintf('.%s', ftype))
            filename = fullfile(searchdir, fs(i).name);
            return
        end
    end
end