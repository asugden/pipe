function out = brain_forces(mouse, date, run, server)       
%registrationMovement returns the relative shift between frames.
    % fixed asks for not change in motion, but absolute motion

    % In an affine transformation matrix, there are five components
    % represented in 4 values- shear x, shear y, scale x, scale y, rotation
    
    % We will assume that rotation is 0 and decompose otherwise.
    % https://www.mathworks.com/discovery/affine-transformation.html
    % [scale_x     shear_x     0]
    % [shear_y     scale_y     0]
    % [translate_x translate_y 0]
    
    % Medial-lateral and anterior-posterior are specific to starsky, 170211

    if nargin < 4, server = []; end
    
    path = pipe.path(mouse, date, run, 'sbx', server);
    afal = [path(1:end-4) '.alignaffine_alltform'];
    if ~exist(afal, 'file')
        disp('Alltform alignment not found. Aligning...');
        pipe.align({path}, 'tbin', 0, 'highpass_sigma', 0, 'save_title', '_alltform');
        
%         afal = [path(1:end-4) '.alignaffine'];
%         if ~exist(afal, 'file')
%             disp('ERROR: Affine alignment file not found.');
%             return;
%         end
%         
%         disp('WARNING: Using downsampled affine alignment.');
    end
    
    al = load(afal, '-mat');

    trans_x = al.trans(:, 3);
    trans_y = al.trans(:, 4);

    xtf = zeros(1, length(al.tform));
    ytf = zeros(1, length(al.tform));
    scale_x = zeros(1, length(al.tform));
    scale_y = zeros(1, length(al.tform));
    shear_x = zeros(1, length(al.tform));
    shear_y = zeros(1, length(al.tform));
    
    if isempty(al.tform{1}) && ~isempty(al.tform{2})
        al.tform{1} = al.tform{2};
    end
        
    for i = 1:length(al.tform)
        xtf(i) = al.tform{i}.T(3, 1);
        ytf(i) = al.tform{i}.T(3, 2);
        scale_x(i) = al.tform{i}.T(1, 1);
        scale_y(i) = al.tform{i}.T(2, 2);
        shear_x(i) = al.tform{i}.T(1, 2);
        shear_y(i) = al.tform{i}.T(2, 1);
    end
       
    trans_x = trans_x + xtf';
    trans_y = trans_y + ytf';
    
    out = struct('transx', trans_x', 'transy', trans_y', 'scalex', scale_x, ...
        'scaley', scale_y, 'shearx', shear_x, 'sheary', shear_y, 'transml', ...
        trans_y', 'transap', trans_x', 'scaleml', scale_y, 'scaleap', scale_x, ...
        'shearml', shear_y, 'shearap', shear_x);
end

