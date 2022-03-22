function [offset, timeOffset, alignCode, spread, wellSubset] = computeDelay(diotime, dioSignal, videotime, videoSignal, samprate, varargin)
% Determines the propere offset between ECU and camera data via convolution

ip = inputParser;
ip.addParameter('wellSubset', [1,4,2]); % wells that are brightest and have the least coverage from the animal can have much lower variance in their estimates and visually have greater overlap
ip.addParameter('quantileViolationPolicy', 'rectify-rmOutlier');
ip.addParameter('ploton', true);
ip.addParameter('method', 'finddelay');
ip.addParameter('alignmentDerivative', 0); % 0: do not take derivative for alignment, 1: take 1st derivative, 2: take the second derivative
ip.addParameter('rectifyAll', true); % Rectify any negativities before alignment
ip.parse(varargin{:})
Opt = ip.Results;

if istable(videoSignal)
    videoSignal = table2array(videoSignal);
end

% PREPROCESS  WELL SIGNALS FOR violations
alignCode = 0; % Assume that no wells need to be thrown out
if ~isempty(Opt.wellSubset)
    subset = Opt.wellSubset;

    % Remove any wells from the subset where dioSignal indicates it's not a used well
    allNanCols = any(isnan(dioSignal(:,subset)),1);
    if any(allNanCols)
        subset(allNanCols) = [];
    end

    % Now let's zero any magnitude violations in the video signal
    % Magnitude violation refers to where the floor of the signal is far lower in abs()
    % than the ceil  of the signal.
    valleyAmpHigherThanPeak = quantile(videoSignal(:, subset),[0.025, 0.975]);
    violations = find(abs(valleyAmpHigherThanPeak(2,:)) < abs(valleyAmpHigherThanPeak(1,:)));
    if contains(Opt.quantileViolationPolicy,'rectify')
        V = videoSignal(:,subset(violations));
        inds = V < -abs(valleyAmpHigherThanPeak(2,violations));
        V(inds) = 0;
        V = bsxfun(@rdivide, V, max(abs(V),[],1));
        videoSignal(:,subset(violations)) = V;
        clear V inds;
    end
    % And remove any outliers  in the video signal
    if contains(Opt.quantileViolationPolicy,'rmOutlier')
        V = videoSignal(:,subset(violations));
        inds = V > valleyAmpHigherThanPeak(2,violations) | V < valleyAmpHigherThanPeak(1,violations);
        V(inds) = 0; % sets their effect/sway to nothing
        V = bsxfun(@rdivide, V, max(abs(V),[],1));
        videoSignal(:,subset(violations)) = V;
        clear V inds;
    end
    % Or simply remove any video signals with  vioolations
    if contains(Opt.quantileViolationPolicy, 'remove')
        subset(violations) = V;
    end
    if isempty(Opt.wellSubset)
        error('Empty subset!')
    elseif numel(Opt.wellSubset) < 2
        warning('Potentially less reliable alignment');
    end
    %assert(all(any(diff(dioSignal(:,Opt.wellSubset))>=1,1)),...
    %    'Not all wells in subset usable'); % Bad to have huge leaps in each of the channels
    alignCode = setdiff(Opt.wellSubset, subset);
    Opt.wellSubset = subset;
    clear subset;
end
wellSubset = Opt.wellSubset; % Whatever the subset is at this point, we will return this

%  WHAT SIGNAL TO ALIGN?
switch Opt.alignmentDerivative
    case 0
        V = videoSignal;
        D = dioSignal;
    case 1
        V = [0 diff(videoSignal)];
        D = [0 diff(dioSignal)];
    case 2 
        V = [0 0 diff(videoSignal)];
        D = [0 0 diff(dioSignal)];
end

% Rectification?
if Opt.rectifyAll
    V(V<0) = 0;
    D(D<0) = 0;
end


% Column-wise convolution  of each signal
% ---------------------------------------
% We will want to maximize how much cue dioSignal and cue from video overlap
tic
timing = onCleanup(@() toc);
switch Opt.method
case 'conv'
    % Convolution will take a long ass time, so let's try to get this
    % into a gpu
    try
        D     = gpuArray(D);
        V = gpuArray(V);
    catch
        D     = gather(D);
        V = gather(V);
    end
    save('test');
    convResults = arrayfun(@(n) conv(D(:,n), V(:,n)), 1:size(D,2),'UniformOutput',false);
    convResults = cat(2,convResults{:});
    % Now we sum across wells
    convResult = sum(convResults,2);
    clear timing;
    D        = gather(D);
    result = gather(convResult);
    axisOfDelay  = -(numel(videotime))+1:numel(diotime)-1;
    % Find best possible delay and time offset
    % ----------------------------------------
    [~, arg] = max(result);
    offset = axisOfDelay(arg);
case 'finddelay'
    tic
    result = finddelay(V(:,Opt.wellSubset), D(:,Opt.wellSubset) );
    offset = nanmedian(result);
    offset = round(offset);
    spread = range(result);

    % - number means to advance the D, position means to lag it
    if offset ~= 0
        stop = min(numel(diotime), numel(videotime));
        start = 1+abs(offset);
        shifttime = circshift(diotime, -offset);
        translator = [shifttime(start:stop) ; videotime(start:stop)]; % we want to subtract final (position 2 of row) -initial(position 1 of row); 
        timeOffset = median(diff(translator)); % the amount to add to D to acheive a match
        if isempty(start:stop)
            warning('Empty overlap! This epoch may be unalignable.')
            alignCode = false;
        end
    else
        translator = [videotime, diotime];
        timeOffset = median(diff(translator));
    end
    toc
    
end

if Opt.ploton
    % Plot the overlap
    % ----------------
    fig('Convolution result');clf;
    colors = cmocean('phase',6);

    switch Opt.method
    case 'conv'
        axs = arrayfun(@(i) subplot(6,1,i), 1:size(dioSignal,2)+1,...
            'UniformOutput', true);
        axes(axs(1));
        cla
        a = area(axisOfDelay, convResult);
        v = vline(offset);
        title('Overall conv value for all wells')
        ylabel('Convolved Amplitude')
        set(v,'LineStyle',':', 'Color', 'k')
        set(a,'FaceColor','black','FaceAlpha',0.25);
        for i = 1:size(dioSignal,2)
            axes(axs(i+1));cla;
            %[x] = util.conv.padA(dioSignal(:,i), offset);
            [x,t] = deal(dioSignal(:,i), diotime);
            a1 = area(x);
            hold on
            [x] = util.conv.padB(videoSignal(:,i), offset);
            h = hline(1);
            set(h,'Color','k','linestyle',':');
            a2 = plot(x + 1);
            set([a1], 'FaceAlpha', 0.5);
            set([a1], 'FaceColor', colors(i+1,:), 'EdgeColor', 'none');
            set([a2], 'Color', 'k');
            ylabel('Convolved Amplitude')
        end
        xlabel('Time Shifts (s)')
        sgtitle('Convolution Result')
        linkaxes(axs(2:end),'x');
    case 'finddelay'

        fig('finddelay-timeOffset');
        axs = arrayfun(@(i) subplot(5,1,i), 1:5);
        for i = 1:5
            axes(axs(i))
            [t,x] = deal(diotime+timeOffset, dioSignal(:,i));
            a1 = area(t,x);
            hold on
            [t,x] = deal(videotime, videoSignal(:,i));
            h = hline(1);
            set(h,'Color','k','linestyle',':');
            a2 = plot(t,x+1);
            set([a1], 'FaceAlpha', 0.5);
            set([a1], 'FaceColor', colors(i+1,:), 'EdgeColor', 'none');
            set([a2], 'Color', 'k');
        end
        xlabel('Videotime, Diotime+timeOffset');
        ylabel('amp');
        sgtitle(sprintf('Offset=%2.1f', timeOffset));
        %fig('finddelay-wholistic');clf;
        %axs = arrayfun(@(i) subplot(2,1,i), 1:2);
        %axes(axs(1));
        %area(videotime, videoSignal);
        %axes(axs(2));
        %area(diotime+timeOffset, dioSignal);
        %linkaxes(axs,'x');

        %fig('finddelay-delay');clf
        %axs = arrayfun(@(i) subplot(5,1,i), 1:5);
        %for i = 1:5
        %    axes(axs(i))
        %    m = min(size(dioSignal,1),size(videoSignal,1));
        %    x = deal(circshift(dioSignal(:,i),-offset));
        %    a1 = area(x(1:m));
        %    hold on
        %    x = deal(videoSignal(:,i));
        %    h = hline(1);
        %    set(h,'Color','k','linestyle',':');
        %    a2 = plot(x(1:m)+1);
        %    set(a1, 'FaceAlpha', 0.5);
        %    set(a1, 'FaceColor', colors(i+1,:), 'EdgeColor', 'none');
        %    set(a2, 'Color', 'k');
        %end
        %xlabel('Videoindex, Dioindex(aftercircshift)');
        %ylabel('amp');
        %sgtitle(sprintf('Offset=%d', offset));
        %linkaxes(axs,'x');
    end
end


