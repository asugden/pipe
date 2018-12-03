function [ output_args ] = dprime(mouse, dates, runs, server, separate_runs)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
    
    if nargin < 4, server = []; end
    if nargin < 2 || isempty(dates), dates = pipe.lab.dates(mouse, server); end
    if nargin < 3, runs = []; end
    if nargin < 5, separate_runs = false; end
    
    fprintf('Mouse\tDate\tRun(s)\td-prime\tHits/Plus\tFalse alarms/Minus\n');
    
    for date = dates
        druns = runs;
        if isempty(druns)
            druns = pipe.lab.runs(mouse, date, server);
        end
        
        nhits = 0;
        nfas = 0;
        nplus = 0;
        nminus = 0;
        used_runs = [];
        for run = druns
            try
                if separate_runs
                    nhits = 0; nfas = 0; nplus = 0; nminus = 0;
                end
                
                ons = pipe.io.trial_times(mouse, date, run, server);
                if isfield(ons, 'condition') && isfield(ons, 'codes') ...
                        && isfield(ons.codes, 'plus') && isfield(ons.codes, 'minus')
                    errs = mod(ons.trialerror, 2);

                    ptrials = ons.condition == ons.codes.plus;
                    nplus = nplus + sum(ptrials);
                    nhits = nhits + sum(errs(ptrials) == 0);

                    mtrials = ons.condition == ons.codes.minus;
                    nminus = nminus + sum(mtrials);
                    nfas = nfas + sum(errs(mtrials) == 1);
                    
                    used_runs = [used_runs run];
                end
                
                if separate_runs && ~isempty(ons)
                    dp = norminv((nhits + 0.5)/(nplus + 1.0)) - norminv((nfas + 0.5)/(nminus + 1.0));
                    fprintf('%s\t%6i\t%3i\t%.3f\t%i/%i\t%i/%i\n', mouse, date, run, dp, nhits, nplus, nfas, nminus);
                end
            end
        end
        
        % loglinear method - see Stanislow and Todorov, 1999
        if ~separate_runs && ~isempty(used_runs)
            dp = norminv((nhits + 0.5)/(nplus + 1.0)) - norminv((nfas + 0.5)/(nminus + 1.0));
            fprintf('%s\t%6i\t%6s\t%.3f\t%i/%i\t%i/%i\n', mouse, date, combine_runs(used_runs), dp, nhits, nplus, nfas, nminus);
        end
    end
end

function str = combine_runs(runs)
    out = {};
    for run = runs
        out{end+1} = num2str(run);
    end
    str = strjoin(out, ',');
end