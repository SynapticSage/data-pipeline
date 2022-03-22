function vecDistributions(vecs)
% function vecDistributions(vecs)
% computes vectorial distributions

nVecs = size(vecs,2);
for i = progress(1:nVecs)
    subplot(nVecs,2,(i-1)*2 + 1);
    histogram(abs(vecs(:,i)));
    subplot(nVecs,2,(i-1)*2 +2);
    polarhistogram(angle(vecs(:,i)));
end
