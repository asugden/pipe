function affine_transforms = turboreg(target_mov, varargin)
%SBXALIGNTURBOREGCORE aligns a file (given by path) using ImageJ's TurboReg
%   NOTE: hardcoded path to ImageJ.

    p = inputParser;
    addOptional(p, 'startframe', 1);  % The frame to start reading from if not xrun
    addOptional(p, 'nframes', 1);  % Number of frames to read if not xrun
    addOptional(p, 'mov_path', []);  % Path to an sbx movie to be read if not xrun
    addOptional(p, 'targetrefs', {});  % Cell array of target TIF paths if xrun
    addOptional(p, 'xrun', false);  % Set to true if cross-run
    addOptional(p, 'binframes', 1);  % Bin frames in time
    addOptional(p, 'binxy', 2);  % How much to bin in xy
    addOptional(p, 'pmt', 1, @isnumeric);  % REMEMBER, PMT is 0-indexed
    addOptional(p, 'optotune_level', []);  % Which optotune level to align
    addOptional(p, 'dfttarget', []);  % We have no idea what this is.
    addOptional(p, 'edges', [0, 0, 0, 0]);  % The edges to be removed
    addOptional(p, 'sigma', 5);  % The sigma of a gaussian blur to be applied after downsampling
    addOptional(p, 'highpass', true);  % If true, subtract gaussian blur. Otherwise, skip
    addOptional(p, 'aligntype', 'affine');  % Can be 'affine' or 'translation'
    if length(varargin) == 1 && iscell(varargin{1}), varargin = varargin{1}; end
    parse(p, varargin{:});
    p = p.Results;
    
    % Fix parameters
    if p.sigma <= 0, p.highpass = false; end    

    % Hardcoded path to ImageJ
    pipe.lab.runimagej();
    
    %% X run
    
    if p.xrun
        % Initialize output and read frames
        affine_transforms = cell(1, length(p.targetrefs));

        combmov = p.targetrefs;
        [y, x] = size(target_mov);
    end
    
    %% Within run
    
    if ~p.xrun
        data = sbxReadPMT(p.mov_path, p.startframe - 1, p.nframes, p.pmt);
            
        % Get the standard edge removal and bin by 2
        data = data(p.edges(3)+1:end-p.edges(4), p.edges(1)+1:end-p.edges(2), :);
        data = binxy(data, p.binxy);

        % If desired, align using dft to a target
        if ~isempty(p.dfttarget)
            c = class(data);
            upsample = 100;
            target_fft = fft2(double(p.dfttarget));
            for i = 1:size(data, 3)
                data_fft = fft2(double(data(:, :, i)));
                [~, reg] = dftregistration(target_fft, data_fft, upsample);
                data(:, :, i) = abs(ifft2(reg));
            end
        end

        % Bin if necessary
        if p.binframes > 1, data = bint(data, p.binframes); end
        [y, x, ~] = size(data);
        
        % Set the correct number of frames
        if size(data, 3) ~= p.nframes
            disp(sprintf('WARNING: frame size difference of %i, %i', p.nframes, size(data, 3)));
            p.nframes = min(p.nframes, size(data, 3));
        end
        affine_transforms = cell(1, p.nframes);

        % Get the save location
        temp_dir = fileparts(target_mov);
        [~, temp_name, ~] = fileparts(p.mov_path);
        temp_name = sprintf('%s\\%s_%i_', temp_dir, temp_name, p.startframe);
        macro_temp_path = [temp_name 'macro.ijm'];
        output_temp_path = [temp_name 'output.txt'];
        finished_temp_path = [temp_name 'done.txt'];
        mov_temp_path = [temp_name 'temp.tif'];

        % Delete the finishing marker if necessary
        if exist(finished_temp_path), delete(finished_temp_path); end

        % Write the tiff of the images to be registered
        writetiff(data, mov_temp_path, class(data));
    end
    
    %% Shared between xrun and within run
    % Get the sizes of the files
    szstr = sprintf('0 0 %i %i ', x - 1, y - 1);
    % Estimate targets the way turboreg does
    targets = [0.5*x 0.15*y 0.5*x 0.15*y 0.15*x 0.85*y 0.15*x 0.85*y ...
        0.85*x 0.85*y 0.85*x 0.85*y];
    targets = round(targets);
    targetstr = sprintf('%i ', targets);
    
    % Create the text for the ImageJ macro
    if strcmp(p.aligntype, 'affine') 
        alignstr = sprintf('"-align -window data %s -window ref %s -affine %s -hideOutput"', ...
            szstr, szstr, targetstr);
    else
        targets = [0.5*x 0.5*y 0.5*x 0.5*y];
        targets = round(targets);
        targetstr = sprintf('%i ', targets);

        alignstr = sprintf('"-align -window data %s -window ref %s -translation %s -hideOutput"', ...
            szstr, szstr, targetstr);
    end
    
    MIJ.start();
    MIJ.createImage('ref', target_mov, false);
    
    % Subtract a blurred image if highpass is desired
    if p.highpass
        MIJ.run('Duplicate...', 'title=refg');
        MIJ.run('Gaussian Blur...', sprintf('sigma=%i', p.sigma));
        
        macro_text = [macro_text 'run("Duplicate...", "title=refg"); ' ...
        'run("Gaussian Blur...", "sigma=' num2str(p.sigma) '"); ' ...
        'imageCalculator("Subtract create 32-bit", "ref", "refg"); ' ...
        'selectWindow("ref"); ' ...
        'close(); ' ...
        'selectWindow("refg"); ' ...
        'close(); ' ...
        'selectWindow("Result of ref"); ' ...
        'rename("ref"); '];
    end
        
    macro_text = [macro_text 'open("' mov_temp_path '"); ' ...
        'rename("stack"); ' ...
        'for (n = 1; n <= nSlices; n++) { ' ...
        ' 	selectWindow("stack"); ' ...
        ' 	setSlice(n); ' ...
        ' 	run("Duplicate...", "title=data"); '];
        
    if p.highpass
        macro_text = [macro_text 'run("Duplicate...", "title=datag"); ' ...
        'run("Gaussian Blur...", "sigma=' num2str(p.sigma) '"); ' ...
        'imageCalculator("Subtract create 32-bit", "data", "datag"); ' ...
        'selectWindow("data"); ' ...
        'close(); ' ...
        'selectWindow("datag"); ' ...
        'close(); ' ...
        'selectWindow("Result of data"); ' ...
        'rename("data"); '];
    end
        
    if strcmp(p.aligntype, 'affine')
        macro_text = [macro_text ' 	run("TurboReg ", ' alignstr '); ' ...
            ' 	print(fo, getResult("sourceX", 0) + " " + getResult("sourceX", 1) ' ...
            '+ " " + getResult("sourceX", 2) + " " + getResult("sourceY", 0) + ' ...
            '" " + getResult("sourceY", 1) + " " + getResult("sourceY", 2)); '];
    else
        macro_text = [macro_text ' 	run("TurboReg ", ' alignstr '); ' ...
            ' 	print(fo, getResult("sourceX", 0) + " 1 0 " + getResult("sourceY", 0) + ' ...
            ' " 1 0"); '];
    end
            
    macro_text = [macro_text ' 	selectWindow("data"); ' ...
        ' 	close(); ' ...
        '} ' ...
        'File.close(fo); ' ...
        'selectWindow("stack"); ' ...
        'close(); ' ...
        'selectWindow("ref"); ' ...
        'close(); ' ...
        'fp = File.open("' finished_temp_path '"); ' ...
        'print(fp, "a"); ' ...
        'File.close(fp); ' ...
        'setBatchMode(false); ' ...
        'eval("script", "System.exit(0);"); '];
    
    macro_text = strrep(macro_text, '\', '\\');
        
    % Save macro
    fo = fopen(macro_temp_path, 'wt');
    fprintf(fo, '%s', macro_text);
    fclose(fo);
    
    % Run Turboreg
    while ~exist(macro_temp_path), pause(1); end
    pause(5);
    status = system(sprintf('"%s" --headless -macro %s', imageJ_path, macro_temp_path));
    
    % Wait until the "done" file has been created and then clean up
    while ~exist(finished_temp_path), pause(1); end
    delete(macro_temp_path);
    delete(mov_temp_path);
    delete(finished_temp_path);
    
    % Read the output of the macro
    fo = fopen(output_temp_path, 'r');
    tform = fscanf(fo, '%f %f %f %f %f %f')';
    fclose(fo);
    delete(output_temp_path);
    tform = reshape(tform, 6, size(tform, 2)/6);
    
    midbin = floor(p.binframes/2);
    if strcmp(p.aligntype, 'affine')
        % Convert to a transformation
        targetgeotransform = targets([3 4 7 8 11 12]);
        targetgeotransform = reshape(targetgeotransform, 2, 3)';

        % Iterate over all times
        for i = 1:length(affine_transforms)
            ftform = reshape(tform(:, i), 3, 2);
            affine_transforms{i*p.binframes-midbin} = fitgeotrans(ftform, targetgeotransform, 'affine');
            affine_transforms{i*p.binframes-midbin}.T(3, 1) = affine_transforms{i*p.binframes-midbin}.T(3, 1)*p.binxy;
            affine_transforms{i*p.binframes-midbin}.T(3, 2) = affine_transforms{i*p.binframes-midbin}.T(3, 2)*p.binxy;
        end
    else
        for i = 1:length(affine_transforms)
            affine_transforms{i*p.binframes-midbin} = affine2d([1 0 0; 0 1 0; (targets(1) - tform(1, i)) (targets(2) - tform(4, i)) 1]);
            affine_transforms{i*p.binframes-midbin}.T(3, 1) = affine_transforms{i*p.binframes-midbin}.T(3, 1)*p.binxy;
            affine_transforms{i*p.binframes-midbin}.T(3, 2) = affine_transforms{i*p.binframes-midbin}.T(3, 2)*p.binxy;
        end
    end
    
    MIJ.exit();
end

