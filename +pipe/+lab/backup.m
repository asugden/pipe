function backup(user, mouse, dates, server, btype, overwrite, verbose)
%BACKUP will backup either raw or processed data to R or anastasia
%   btype is the backup type, can be empty (copy to R), 'raw' (copy raw to 
%   R), 'processed' (copy processed to R), 'anastasia' (copy all to
%   anastasia), or 'full' (copy all to R and anastasia)

    if nargin < 4, server = []; end
    if nargin < 3 || isempty(dates), dates = pipe.lab.dates(mouse, server); end
    if nargin < 5, btype = 'raw'; end
    if nargin < 6, overwrite = false; end
    if nargin < 7, verbose = true; end

    rbase = 'R:\Andermann_Lab\active\2photon\';
    nasbase = '\\anastasia\data\2p\';
    % Note that cell-clicking paths are hardcoded below
    
    switch btype
        case 'raw'
            archivebase = fullfile(rbase, user);
            rawData(mouse, dates, server, archivebase, overwrite, verbose);
        case 'processed'
            archivebase = fullfile(rbase, user);
            processedData(mouse, dates, server, archivebase, overwrite, verbose);
        case 'anastasia'
            archivebase = fullfile(nasbase, user);
            rawData(mouse, dates, server, archivebase, overwrite, verbose);
            processedData(mouse, dates, server, archivebase, overwrite, verbose);
        case 'full'
            archivebase = fullfile(rbase, user);
            rawData(mouse, dates, server, archivebase, overwrite, verbose);
            processedData(mouse, dates, server, archivebase, overwrite, verbose);
            archivebase = fullfile(nasbase, user);
            rawData(mouse, dates, server, archivebase, overwrite, verbose);
            processedData(mouse, dates, server, archivebase, overwrite, verbose);
    end
end



function rawData(mouse, dates, server, archivebase, overwrite, verbose)
%BACKUPRAWDATA Copy raw data to R, renaming files to match their enclosing
%   mouse/date/run if necessary
%   Does not overwrite unless overwrite flag is set

%   Backs up the following file types:
%   .sbx
%   .mat (info file)
%   .ephys
%   _eye.mat
%   _quadrature.mat
%   .bhv

    % Set defaults
    if nargin < 4, server = []; end
    if nargin < 3 || isempty(dates), dates = pipe.lab.dates(mouse, server); end
    if nargin < 5, overwrite = false; end
    if nargin < 6, verbose = true; end
    
    if ~exist(fullfile(archivebase, upper(mouse)), 'dir')
        mkdir(fullfile(archivebase, upper(mouse)));
    end
   
    % Iterate over dates
    for date = dates
        datebase = fullfile(archivebase, upper(mouse), sprintf('%6i_%s', date, mouse));        
        if ~exist(datebase, 'dir'), mkdir(datebase); end
        
        runs = pipe.lab.runs(mouse, date, server);
        for run = runs
            fprintf('Moving raw data to %s: %s %6i %03i\n', archivebase, mouse, date, run);
            destbase = fullfile(datebase, sprintf('%6i_%s_%03i', date, mouse, run));
            if ~exist(destbase, 'dir'), mkdir(destbase); end
            
            % SBX and INFO files
            sbx = pipe.path(mouse, date, run, 'sbx', server);
            if isempty(sbx)
                if verbose
                    fprintf('  WARNING: SBX file not found for %s %6i %03i\n', mouse, date, run);
                end
            else
                [srcbase, name, ext] = fileparts(sbx);
                newname = sprintf('%s_%6i_%03i.sbx', mouse, date, run);
                copyWithChecks('sbx', srcbase, destbase, [name ext], newname, overwrite, verbose);

                newname = sprintf('%s_%6i_%03i.mat', mouse, date, run);
                copyWithChecks('info', srcbase, destbase, [name '.mat'], newname, overwrite, verbose);
            end
                
            % EPHYS file
            ephys = pipe.path(mouse, date, run, 'ephys', server);
            if isempty(ephys)
                if verbose
                    fprintf('  WARNING: EPHYS file not found for %s %6i %03i\n', mouse, date, run);
                end
            else
                [srcbase, name, ext] = fileparts(ephys);
                newname = sprintf('%s_%6i_%03i.ephys', mouse, date, run);
                copyWithChecks('ephys', srcbase, destbase, [name ext], newname, overwrite, verbose);
            end
            
            % EYE file
            eye = pipe.path(mouse, date, run, 'pupil', server);
            if isempty(eye)
                if verbose
                    fprintf('  WARNING: EYE file not found for %s %6i %03i\n', mouse, date, run);
                end
            else
                [srcbase, name, ext] = fileparts(eye);
                newname = sprintf('%s_%6i_%03i_eye.mat', mouse, date, run);
                copyWithChecks('eye', srcbase, destbase, [name ext], newname, overwrite, verbose);
            end
            
            % QUADRATURE file
            quad = pipe.path(mouse, date, run, 'quad', server);
            if isempty(quad)
                if verbose
                    fprintf('  WARNING: QUADRATURE file not found for %s %6i %03i\n', mouse, date, run);
                end
            else
                [srcbase, name, ext] = fileparts(quad);
                newname = sprintf('%s_%6i_%03i_quadrature.mat', mouse, date, run);
                copyWithChecks('quadrature', srcbase, destbase, [name ext], newname, overwrite, verbose);
            end
            
            % BHV file
            bhv = pipe.path(mouse, date, run, 'bhv', server);
            if isempty(bhv)
                if verbose
                    fprintf('  WARNING: BHV file not found for %s %6i %03i\n', mouse, date, run);
                end
            else
                [srcbase, name, ext] = fileparts(bhv);
                newname = sprintf('%s_%6i_%03i.bhv', mouse, date, run);
                copyWithChecks('bhv', srcbase, destbase, [name ext], newname, overwrite, verbose);
            end
        end
    end
end


function processedData(mouse, dates, server, archivebase, overwrite, verbose)
%BACKUPRAWDATA Copy raw data to R, renaming files to match their enclosing
%   mouse/date/run if necessary
%   Does not overwrite unless overwrite flag is set

%   Backs up the following file types:
    backups = {...
        'align', ...
        'alignaffine', ...
        'alignxy', ...
        'decon', ...
        'dparams', ...
        'f2p', ...
        'ica', ...
        'icamasks', ...
        'icanmf', ...
        'onsets', ...
        'pdiam', ...
        'pmask', ...
        'signals', ...
    };
    % And .simpcell, .simpglm, and .clicked (which is in a different location)

    % Set defaults
    if nargin < 3, server = []; end
    if nargin < 2 || isempty(dates), dates = pipe.lab.dates(mouse, server); end
    if nargin < 5, overwrite = false; end
    if nargin < 6, verbose = true; end
    
    if ~exist(fullfile(archivebase, upper(mouse)), 'dir')
        mkdir(fullfile(archivebase, upper(mouse)));
    end
   
    % Iterate over dates
    for date = dates
        datebase = fullfile(archivebase, upper(mouse), sprintf('%6i_%s', date, mouse));        
        if ~exist(datebase, 'dir'), mkdir(datebase); end
        
        copiedglm = false;
        runs = pipe.lab.runs(mouse, date, server);
        for run = runs
            fprintf('Moving processed data to %s: %s %6i %03i\n', archivebase, mouse, date, run); 
            destbase = fullfile(datebase, sprintf('%6i_%s_%03i', date, mouse, run));
            if ~exist(destbase, 'dir'), mkdir(destbase); end
            
            for b = 1:length(backups)
                path = pipe.path(mouse, date, run, backups{b}, server);
                if ~isempty(path) && exist(path, 'file')
                    [srcbase, name, ext] = fileparts(path);
                    newname = sprintf('%s_%6i_%03i.%s', mouse, date, run, backups{b});
                    copyWithChecks(backups{b}, srcbase, destbase, [name ext], newname, overwrite, verbose);
                end
            end
            
            path = pipe.path(mouse, date, run, 'simpcell', server);
            if ~isempty(path) && exist(path, 'file')
                [srcbase, name, ext] = fileparts(path);
                newname = sprintf('%s_%6i_%03i.simpcell', mouse, date, run);
                copyWithChecks('simpcell', srcbase, datebase, [name ext], newname, overwrite, verbose);
            end
            
            if ~copiedglm
                path = pipe.path(mouse, date, run, 'simpglm', server);
                if ~isempty(path) && exist(path, 'file')
                    [srcbase, name, ext] = fileparts(path);
                    newname = sprintf('%s_%6i.simpglm', mouse, date);
                    copyWithChecks('simpglm', srcbase, datebase, [name ext], newname, overwrite, verbose);
                    copiedglm = true;
                end
            end
            
            path = cellClickedPath(mouse, date, run, server);
            if ~isempty(path)
                [srcbase, name, ext] = fileparts(path);
                newname = sprintf('%s_%6i_%03i_clicked.txt', mouse, date, run);
                copyWithChecks('clicked', srcbase, destbase, [name ext], newname, overwrite, verbose);
            end
        end
    end
end


function status = copyWithChecks(ftype, srcbase, destbase, src, dest, overwrite, verbose)
%COPYWITHCHECKS Copy a file, checking that it needs to be copied,
% throwing errors, and displaying results

    if nargin < 7, verbose = true; end
    
    if ~strcmp(src, dest) && verbose
        fprintf('  WARNING: Changing %s name of %s to %s\n', upper(ftype), src, dest);
    end

    do_copy = false;
    if overwrite || ~exist(fullfile(destbase, dest), 'file')
        do_copy = true;
    else % file exists and we don't want to force an overwrite
        orig_attr = dir(fullfile(srcbase, src));
        dest_attr = dir(fullfile(destbase, dest));
        if orig_attr.bytes ~= dest_attr.bytes || orig_attr.datenum > dest_attr.datenum
            do_copy = true;
            fprintf('  UPDATED %s file %s\n', upper(ftype), src);
        elseif verbose
            fprintf('  SKIPPING %s file %s\n', upper(ftype), src);
        end
    end
    
    if do_copy
        status = copyfile(fullfile(srcbase, src), fullfile(destbase, dest));
        if status ~= 1
            error('STOPPING: could not copy %s file %s', upper(ftype), src);
        end
    end
end


function path = cellClickedPath(mouse, date, runs, server)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 4, server = []; end
    if nargin < 3 || isempty(runs), runs = pipe.lab.runs(mouse, date, server); end
    if isnumeric(date), date = num2str(date); end
    
    % Account for using any server
    datapath = '\\tolman\webdata\clicked\';
        
    matchstr = sprintf('%s_%s_%03i', date, mouse, runs(end));
    maxdate = -1;
    maxtime = -1;
    path = [];

    % Get the clicked cell file
    fs = dir(datapath);
    for i = 1:length(fs)
        if ~fs(i).isdir
            if length(fs(i).name) > length(matchstr)
                if strcmp(fs(i).name(1:length(matchstr)), matchstr)
                    timestampdate = str2num(fs(i).name(length(matchstr)+2:length(matchstr)+7));
                    timestamptime = str2num(fs(i).name(length(matchstr)+9:length(matchstr)+14));
                    
                    if timestampdate > maxdate && timestamptime > maxtime
                        maxdate = timestampdate;
                        maxtime = timestamptime;
                        path = [datapath fs(i).name];
                    end
                end
            end
        end
    end
    
    if isempty(path)
        if strcmpi(hostname, 'megatron')
            datapath = 'D:\twophoton_data\2photon\scan\jobdb\webserver\clicked\';
        else
            datapath = '\\twophoton_data\2photon\scan\jobdb\webserver\clicked\';
        end
        
        nmftext = '';
        matchstr = sprintf('%s_%s_%03i%s', date, mouse, runs(end), nmftext);
        maxdate = -1;
        maxtime = -1;
        path = [];

        % Get the clicked cell file
        fs = dir(datapath);
        for i = 1:length(fs)
            if ~fs(i).isdir
                if length(fs(i).name) > length(matchstr)
                    if strcmp(fs(i).name(1:length(matchstr)), matchstr)
                        timestampdate = str2num(fs(i).name(length(matchstr)+2:length(matchstr)+7));
                        timestamptime = str2num(fs(i).name(length(matchstr)+9:length(matchstr)+14));

                        if timestampdate > maxdate && timestamptime > maxtime
                            maxdate = timestampdate;
                            maxtime = timestamptime;
                            path = [datapath fs(i).name];
                        end
                    end
                end
            end
        end
    end
end
