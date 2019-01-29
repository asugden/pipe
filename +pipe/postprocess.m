function postprocess(mouse, date, varargin)
%SBXPULLSIGNALS After an icamasks file has been created, pull signals and 
%   run simplifycellsort

    p = inputParser;
    % ---------------------------------------------------------------------
    addOptional(p, 'runs', []);  % A list of runs to use. If empty, use all runs
    addOptional(p, 'server', []);  % Server on which data resides
    addOptional(p, 'force', false);  % Overwrite files if they exist
    addOptional(p, 'job', false);  % Set to true to run as a job, set to false to run immediately.
    addOptional(p, 'pmt', 0);  % PMT to use for extraction
    addOptional(p, 'optotune_level', []);  % Not yet implemented
    addOptional(p, 'movie_type', []);  % Set if using non-standard registration and want to use an alternate movie type such as .sbxreg
    addOptional(p, 'registration_path', []);  % Use a non-standard registration path
    addOptional(p, 'icapath', []);  % Path to ICA file, expected to be in the last run directory if empty
    addOptional(p, 'icarun', -1);  % ICA run number, required for looking for clicked cells
    
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    if nargin < 2, error('Date not set\n'); end
    
    %% Clean up the inputs

    if isempty(p.runs), p.runs = pipe.lab.runs(mouse, date, p.server); end
    if ~isnumeric(date), date = str2num(date); end
    
    % Prefer cellclicking, but fall back on icamasks
    % Also, will only work if ICA file exists
    if isempty(p.icapath)
        icarun = runs(end);
        icapath = sbxPath(mouse, date, icarun, 'ica', 'server', p.server);
        if isempty(icapath)
            error('ICA not yet created for %s %s %02i', mouse, date, icarun);
        end
    else
        if p.icarun < 0
            error('ICA run number not set (p.icarun)');
        end
        icapath = p.icapath;
        icarun = p.icarun;
    end
    
    % Make sure that icarun is the last member of getCellClicked
    ccruns = [runs icarun];
    
    useicamasks = false;
    [seld, erosions] = getCellClicked(mouse, date, ccruns, false, p.nmf);
    if isempty(seld) && isempty(p.icapath)
        icamaskspath = sbxPath(mouse, date, icarun, 'icamasks', 'server', p.server);
        if ~isempty(icamaskspath)
            disp('CellClick file not found. Using .icamasks instead.');
            useicamasks = true;
            load(icamaskspath, '-mat');
        else
            fprintf('%s %s %02i not clicked yet.\n', mouse, date, icarun);
            return;
        end
    end
    
    
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

