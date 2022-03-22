function [wells] = quantile(frames, rects, varargin)
% Compute the quantile activations of each well.
ip = inputParser;
ip.addParameter('ploton', true);
ip.addParameter('wellIdentities', [],...
    @(x) iscellstr(x) || isstring(x));
ip.addParameter('outlierRemove', [0.01, 0.99]); % Remove outliers
ip.parse(varargin{:})
Opt = ip.Results;
Opt.wellIdentities = string(Opt.wellIdentities);

if Opt.ploton
    clf
    colors = cmocean('phase',6);
end

wells = zeros(size(frames,4), size(rects,1));
for w =  1:size(rects,1)
    Xi = rects(w,2);
    Yi = rects(w,1);
    Xf = Xi+rects(w,4);
    Yf = Yi+rects(w,3);

    % Extract ROI
    % -----------
    F = frames(Xi:Xf, Yi:Yf,:,:);
    F = permute(F, [4, 1, 2, 3]);
    F = single(F);
    %F = zscore(F,0,1); % zscore to account for scale TODO rather than a zscore around a mean, maybe need X-median(X)/std(X)
    if ~isempty(Opt.outlierRemove)
        high = quantile(F, Opt.outlierRemove(2), 1);
        high = bsxfun(@ge, F, high);
        low = quantile(F, Opt.outlierRemove(1), 1);
        low = bsxfun(@le, F, low);
        F(high) = nan; % This point no longer will contribute to the correlation
        F(low) = nan; % This point no longer will contribute to the correlation
    end
    F = bsxfun(@rdivide,...
               bsxfun(@minus, F, nanmean(F,1)),nanstd(F,1)); % zscore to account for scale TODO rather than a zscore around a mean, maybe need X-median(X)/std(X)
    F(isnan(F)) = 0;
    F = reshape(F, size(F,1), []); % Reshape such that all pixels per frame in column
    F = F/size(F,1); % Devide each value by total number of frames
    F = nanmean(F,2); % mean pixels per frrame
    F = F/max(F); % divide by maximum attainable signal.
    wells(:,w) = F(:);
    if Opt.ploton
        fig('well quantile');
        hold on;
        a=area(smoothdata(F,'lowess',3), 'FaceColor', colors(w+1,:), 'EdgeAlpha',0);
        set(a,'FaceAlpha',0.5);
    end
end

if Opt.ploton
    legend(string(1:5))
end
