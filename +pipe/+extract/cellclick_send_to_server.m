function cellclick_send_to_server(mouse, date, runs, icapath, force, axon, server, nmf)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

    if nargin < 7, server = []; end
    if nargin < 3 || isempty(runs), runs = pipe.lab.runs(mouse, date, server); end    
    if nargin < 5 || isempty(force), force = false; end
    if nargin < 6 || isempty(axon), axon = false; end
    if nargin < 8 || isempty(nmf), nmf = false; end
    
    icarun = runs(end);
    nmftext = '';
    if nargin < 4 || isempty(icapath)
        icapath = pipe.path(mouse, date, icarun, 'ica', server);
        if nmf || isempty(icapath)
            icapath = pipe.path(mouse, date, icarun, 'icanmf', server);
            nmftext = '_nmf';
        end
    end
    
    datapath = pipe.lab.webserver();
    
    if ischar(date), date = str2num(date); end
    mdp = sprintf('%s%s_%i_%03i%s\\', datapath, mouse, date, icarun, nmftext);
    zeropos = 5;  % height above zero relative to below
    minim = 20;  % Minimum image width
    erosions = [1.0, 0.85, 0.7, 0.5, 0.35, 0.2, 0.12, 0.05];
    
    if ~exist(mdp) || force
        mkdir(mdp)
        ica = load(icapath, '-mat');
        
        mnimpath = sprintf('%smean-image.jpg', mdp);
        pipe.extract.save_scaled_image(mnimpath, ica.icaguidata.movm);
        
        roipath = sprintf('%srois.txt', mdp);
        fp = fopen(roipath, 'w');
        fprintf(fp, '%i', length(ica.icaguidata.ica));
        fclose(fp);
        
        impos = zeros(length(ica.icaguidata.ica), 3);
        masks = cell(1, length(ica.icaguidata.ica));
        erosionmasks = cell(1, length(ica.icaguidata.ica));
        
        for tr = 1:length(ica.icaguidata.ica)
            trpath = sprintf('%strace-%04i.jpg', mdp, tr);
            impath = sprintf('%sfilter-%04i.png', mdp, tr);
            erpath = sprintf('%smask-%04i.json', mdp, tr);
            
            pipe.extract.save_trace_image(trpath, ica.icaguidata.ica(tr).trace, zeropos);
            [impos(tr, 1), impos(tr, 2), impos(tr, 3)] = ...
                pipe.extract.save_filter_image(impath, ica.icaguidata.ica(tr).filter, minim);
            [erosionmasks{tr}, finerosions] = ...
                pipe.extract.save_erosion_masks([], ica.icaguidata.ica(tr).filter, erosions, ~axon);
            masks{tr} = pipe.extract.erosionmask(ica.icaguidata.ica(tr).filter, 0.7, ~axon);
        end
        
        impospath = sprintf('%simage-positions.json', mdp);
        fp = fopen(impospath, 'w');
        fprintf(fp, '{"positions":[');
        for tr = 1:length(ica.icaguidata.ica)
            if tr > 1, fprintf(fp, ','); end
            fprintf(fp, '[%i,%i,%i]', impos(tr, 1), impos(tr, 2), impos(tr, 3));
        end
        fprintf(fp, ']}');
        fclose(fp);
        
        ermaskpath = sprintf('%serosion-masks.json', mdp);
        fp = fopen(ermaskpath, 'w');
        fprintf(fp, '{"erosions":[');
        for (e = 1:length(finerosions))
            if (e > 1), fprintf(fp, ','); end
            fprintf(fp, '%0.2f', finerosions(e));
        end
        fprintf(fp, '], "masks":[');
        for tr = 1:length(ica.icaguidata.ica)  % For cell
            if tr > 1, fprintf(fp, ','); end
            fprintf(fp, '[');
            for i = 1:length(erosionmasks{tr})  % For erosion level
                if i > 1, fprintf(fp, ','); end
                fprintf(fp, '[');
                for j = 1:length(erosionmasks{tr}{i})  % Mask array
                    if j > 1, fprintf(fp, ','); end
                    fprintf(fp, '%i', erosionmasks{tr}{i}(j));
                end
                fprintf(fp, ']');
            end
            fprintf(fp, ']');
        end
        fprintf(fp, ']}');
        fclose(fp);
        
        overlappath = sprintf('%soverlaps.json', mdp);
        pipe.extract.save_overlap_masks(overlappath, masks);
    end
end

