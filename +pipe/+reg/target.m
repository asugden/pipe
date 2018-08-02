function frame = target(path, pmt, otlevel, bin, offset_beginning, refsize, edges, equaledges)
%SBXALIGNTARGETCORE Aligns an sbx target file given by path. Assumes that
%	the used pmt is 0 or green

    % Parameters --------------------------
    %refsize = 500; % How many frames (500)
    upsample = 100; % Upsampling for alignment
    % -------------------------------------

    % example: pmt = 1, bin = 2, offset_beginning = 500, refsize = 500
    
    
    % Open first refsize frames of target file
    ref = pipe.imread(path, offset_beginning, refsize, pmt, otlevel);
    c = class(ref);
    
    % Equalize edges for easy of return affine transform to correct size
    if nargin > 7 && equaledges
        edges(1:2) = edges(1:2)/size(ref, 2);
        edges(3:4) = edges(3:4)/size(ref, 1);
        maxedges = max(edges);
        edges(1:2) = round(maxedges*size(ref, 2));
        edges(3:4) = round(maxedges*size(ref, 1));
    end
    
    ref = ref(edges(3)+1:end-edges(4), edges(1)+1:end-edges(2), :);
    
    % Bin, if necessary
    if bin > 1, ref = pipe.proc.binxy(ref, bin); end
    
    % First, unaligned reference
    fref = squeeze(mean(ref, 3));
    
    % Align reference files
    for repeats = 1:3 % 3 repetitions to register targets well
        target_fft = fft2(double(fref));
        for i = 1:size(ref, 3)
            data_fft = fft2(double(ref(:, :, i)));
            [~, reg] = pipe.reg.dft(target_fft, data_fft, upsample);
            ref(:, :, i) = abs(ifft2(reg));
        end
        fref = squeeze(mean(ref, 3));
    end
    
    % Compress the aligned reference files and convert back to original
    % class
    frame = squeeze(mean(ref, 3));
    frame = cast(frame, c);
end

