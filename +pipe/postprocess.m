function postprocess(mouse, date, runs, varargin)
%SBXPULLSIGNALS After an icamasks file has been created, pull signals and 
%   run simplifycellsort

    p = inputParser;
    % ---------------------------------------------------------------------
    % Most important variables
    addOptional(p, 'extract_from_cleaned', true);  % Extract from PCA cleaned data if it exists
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    if nargin < 2, date = []; end
    if nargin < 3, runs = []; end
    if ~isempty(date) && isempty(runs), runs = pipe.lab.runs(mouse, date); end
    
    %%



    % Usually run on all runs in a single folder with the first as a target
    if nargin < 4, server = []; end
    if nargin < 3 || isempty(runs), runs = sbxRuns(mouse, date, server); end
    if nargin < 5, use_cleaned = true; end
    if nargin < 6, scstyle = []; end
    if nargin < 7, stimtiff = false; end
    if nargin < 8, alignmaskcheck = false; end
    
    % Extract all signals files
    sbxSignals(mouse, date, runs, 'usecleaned', use_cleaned, 'server', server);
    
    % Get masks and pull signals
    for i = 1:length(runs)
        run = runs(i);

        % Save a simplified data
        if ~isempty(scstyle) && strcmp(scstyle, 'dura')
            simpcellDura(mouse, date, run);
        else
            simplifycellsort(mouse, date, run, server);
        end
        
        % Make a stimulus TIFF
        if stimtiff
            sbxStimulusTiff(mouse, date, run, [], server);
        end
    end
    
    % Make a masked stimulus TIFF movie
    if alignmaskcheck
        try
            sbxAlignmentMaskCheck(mouse, date, [], server);
        catch
            disp("Failed to run sbxAlignmentMaskCheck. Does reg_affine\x-run-reg-test.tif exist?")
        end
    end
    
    if isempty(scstyle)
        savepath = sbxPath(mouse, date, 2, 'simpglm', 'server', server);
        if ~exist(savepath)
            glmPoisson(mouse, date, 'savepath', savepath, 'server', server);
        end
    end
    
    % Get the max ROI images
    [~, ~, traces1, tlens1] = pdMasksTraces(mouse, date, runs, [], server);
    maxims1 = pdPeakImage(mouse, date, runs, traces1, tlens1, [], server);
end 

