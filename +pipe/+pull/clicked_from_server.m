function [selected, erosions] = clicked_from_server(mouse, date, run, icapath)
% CLICKED_FROM_SERVER Get a list of which ROIs were "clicked" or selected
%   and what the preferred erosions were.
%   axon flag allows discontinuous ROIs'
    if nargin < 4, icapath = []; end

    % Account for using any server
    datapath = pipe.lab.webserver(true);
    
    matchstr = sprintf('%d_%s_%03i', date, mouse, run);
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
    
    % Prepare output and account for not finding the file
    selected = [];
    erosions = [];
    
    if isempty(path), return; end
    
    if ~isempty(icapath)
        % Compare mod times of the click file and ica data to make sure that
        % the click file is newer.
        click_dir = dir(path);
        click_mod_time = click_dir.datenum;
        icadata_dir = dir(icapath);
        icadata_mod_time = icadata_dir.datenum;
        if icadata_mod_time > click_mod_time
            fprintf('ICA data newer than click file, needs to be re-clicked: %s %d\n', mouse, date);
            return
        end
    else
        fprintf('Unknown icapath, not checking for data consistency: %s %d\n', mouse, date);
    end

    fp = fopen(path, 'r');
    filevals = fscanf(fp, '%i\t%f\n');
    fclose(fp);
    filevals = reshape(filevals, 2, length(filevals)/2);
    
    selected = logical(filevals(1, :));
    erosions = filevals(2, :);
end

