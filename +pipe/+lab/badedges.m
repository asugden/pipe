function out = badedges(path)
%BADEDGES These are the edge bands that should be removed. In the future,
%   variations to edge removal should be added to each user's external
%   pipeline code. Other values are left in the pipeline to keep expected
%   values consistent.

    % Left, right, top bottom
    % FORMERLY out = [50, 70, 5, 5];
    % Changed for all days beginning on 170526
    out = [60, 80, 10, 20];
    
    if nargin > 0
        try
            [~, fname, ~] = fileparts(path);
            if ~isempty(strfind(fname, 'DL'))
                out = [80, 80, 10, 10]; % used to be 60,100,10,10. Jun set it to 80,80,10,10
            elseif ~isempty(strfind(fname, 'ALOA'))
                out = [140, 140, 10, 10]; %for NMF
                %out = [270, 300, 80, 80]; %for affine alignment
                %out = [210, 210, 70, 70]; % for affine alignment
            elseif ~isempty(strfind(fname, 'CB209')) && ~isempty(strfind(fname, '170620'))
                out = [64, 80, 38, 8];
            elseif ~isempty(strfind(fname, 'OA38')) && ~isempty(strfind(fname, '171107'))
                out = [60, 80, 10, 55];
            elseif ~isempty(strfind(fname, 'CB173'))
                out = [50, 70, 5, 5];
            elseif ~isempty(strfind(fname, 'YL'))
                out = [100, 100, 80, 80]; 
            elseif ~isempty(strfind(fname, 'OA27')) || ~isempty(strfind(fname, 'OA26')) ...
                   || ~isempty(strfind(fname, 'OA67')) || ~isempty(strfind(fname, 'VF226'))
                out = [64, 64, 20, 20]; % to ~match remove_edges_mov.m
            end
        end
    end
end
