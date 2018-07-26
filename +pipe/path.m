function  out = path(mouse, date, run, ftype, server, varargin)
%PATH Returns the path to a data directory

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

    out = pipe.lab.datapath(mouse, date, run, ftype, server, p);
end

