function y = chinorm(x, mu, sigma, k, scale, xoffset, normal_weight)
%CHINORM Return the combination of a chi-square and normal distribution
    norm = normpdf(x, mu, sigma);
    chi2 = chi2pdf(x*scale + xoffset, k)*scale;
    y = normal_weight*norm + (1 - normal_weight)*chi2;
end

