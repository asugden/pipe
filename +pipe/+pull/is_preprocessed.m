function proc = is_preprocessed(mouse, date, runs, server, varargin)
% IS_PREPROCESSED Checks whether a mouse, date, and run has been
%   preprocessed

    % Because the .ica file is found in the 
    % last run of a group, all runs are 
    % necessary. This defaults to all runs 
    % from a day.

    if nargin < 3, runs = []; end
    if nargin < 4, server = []; end
    
    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'not_legacy', false);  % If true, only accept non-legacy 
                                 % processing (after Rohan's code)
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;

    %% Check
    
    proc = false;
    if isempty(runs), runs = pipe.lab.runs(mouse, date, server); end
    
    icarun = runs(end);
    icapath = pipe.path(mouse, date, icarun, 'ica', server);
    
    if ~isempty(icapath)
        proc = true;
        
        if p.not_legacy
            ica = load(icapath, '-mat');
            if ~isfield(ica.icaguidata, 'pars')
                proc = false;
            end
        end
    end

end