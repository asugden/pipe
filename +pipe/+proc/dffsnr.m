function snr = dffsnr(f)
    % DFFSNR Return the combined signal-to-noise ratio of a raw
    % fluorescence trace f. The SNR is a combination of the total spiking
    % activity and the peak amplitude of the spiking activity relative to
    % the noise. The noise is calculated by fitting a Gaussian to the 
    % histogram for all values lower than the mode.
    
    [noise_, mu_, sigma_] = pipe.proc.dffnoise(f);
    snr = 1 - noise_*sigma_;
    snr = (snr*snr - 0.6)/0.4;
end