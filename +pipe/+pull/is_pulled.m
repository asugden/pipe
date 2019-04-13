function proc = is_pulled(mouse, date, run, server, varargin)
% IS_PREPROCESSED Checks whether a mouse, date, and run has been
%   preprocessed

    % Because the .ica file is found in the 
    % last run of a group, all runs are 
    % necessary. This defaults to all runs 
    % from a day.

    if nargin < 4, server = []; end
    
    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'runs', []);  % All runs are required for identifying .ica file
    addOptional(p, 'not_legacy', false);  % If true, only accept non-legacy 
                                 % processing (after Rohan's code)
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;

    %% Check
    
    proc = false;
    if isempty(p.runs), p.runs = pipe.lab.runs(mouse, date, server); end
    
    % Check if the preceding step has been completed
    if ~pipe.pull.is_clicked(mouse, date, p.runs, server, ...
                                  'not_legacy', p.not_legacy)
        return;
    end
    
    sig_path = pipe.path(mouse, date, run, 'signals', server);
    
    if ~isempty(sig_path)
        proc = true;
    end
end