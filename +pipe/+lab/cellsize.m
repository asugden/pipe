function [cellhalfwidth, minarea, maxarea, downsample_xy] = ...
    cellsize(objective, zoom, cellhalfwidth)
%CELLSIZE Return the cell sizes dependend on objective and zoom

    if strcmpi(objective, 'nikon16x')
        cellhalfwidth = (zoom/1.6)*2.5;
        minarea = round((zoom/1.6)*25);
        maxarea = round((zoom/1.6)*500);
        downsample_xy = 2;
    elseif strcmpi(objective, 'olympus25x')
        cellhalfwidth = (zoom/1.6)*2.5*(25.0/16);
        minarea = round((zoom/1.6)*25)*((25.0/16)*(25.0/16));
        maxarea = round((zoom/1.6)*500)*((25.0/16)*(25.0/16));
        downsample_xy = 2;
    elseif strcmpi(objective, '4x')
        %GRIN FOV is 500microns with 2.7x mag making it 185microns across
        cellhalfwidth = (zoom/6.7)*15;
        minarea = round((zoom/6.7)*40);
        maxarea = round((zoom/6.7)*2000);
        downsample_xy = 4;
    else
        minarea = round(cellhalfwidth*2.8);
        maxarea = round(cellhalfwidth*200);
        downsample_xy = 2;
    end
end

