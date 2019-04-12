function [ output_args ] = write_sbx(movie, path, date, run, server, varargin)
%WRITE_SBX Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 5, server = []; end

    if nargin >= 4
        mouse = path;
        path = pipe.lab.rundir(path, date, run, server);
        path = fullfile(path, sprintf('%s_%06i_%03i.sbx', mouse, date, run));
    end

    p = inputParser;
    addOptional(p, 'force', false);  % Overwrite if true
    parse(p, varargin{:});
    p = p.Results;
    
    % Loop and save
    if exist(path, 'file') && ~p.force
        return;
    end
    
    
    info = pipe.io.write_sbxinfo(path, 'movie', movie);
    if ndims(movie) == 4
        info.nframes = size(movie, 4);
    elseif ndims(movie) == 3
        info.nframes = size(movie, 3);
    elseif ismatrix(movie)
        info.nframes = 1;
    end
    
    rw = pipe.io.RegWriter(path, info, 'sbx', p.force);
    rw.write(movie);
    rw.close();


end

