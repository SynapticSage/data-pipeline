function varargout = testPos(animID, dayepoch, varargin)
% function varargout = testPos(animID, dayepoch, varargin)
% Compares rawpos to pos for dayepoch animal=animID

ip = inputParser;
ip.addParameter('tail', 0);
ip.addParameter('pause', 1/60);
ip.addParameter('fullvideo', false);
ip.addParameter('frames', []);
ip.addParameter('preFetchFrames', false);
ip.addParameter('endframe', -1);
ip.parse(varargin{:})
Opt = ip.Results;

F = fig('Test rawpos and raw');
frame = giveframe(1,animID,dayepoch, Opt);
im=imagesc(frame);
hold on;
p = animatedline();
r = animatedline();
tit=title('');

pos = ndb.load(animID, 'pos', 'indices', dayepoch);
pos = ndb.get(pos, dayepoch);
rawpos = ndb.load(animID, 'rawpos', 'indices', dayepoch);
rawpos = ndb.get(rawpos, dayepoch);
P = pos.data;
R = rawpos.data;
set(p,'LineStyle',':', 'Marker', '^', 'MarkerSize', 10, 'MarkerFaceColor', 'auto', 'Color', 'green');
set(r,'LineStyle',':', 'Marker', 'V', 'MarkerSize', 10, 'MarkerFaceColor', 'auto', 'Color', 'red');
cmperpix = rawpos.cmperpixel;

frames = cell(size(R,1),1);
finished = false;
%cleanup = onCleanup(@() save('/tmp/tmpvid.mat','frames','-v7.3'));
if Opt.endframe == -1
    Opt.endframe = size(R,1);
else
    Opt.endframe = min(size(R,1),Opt.endframe);
end
for t = progress(1:Opt.endframe)
    if Opt.fullvideo
        frame = giveframe(t,animID,dayepoch, Opt);
        im.CData = frame;
    end
    x = R(max(t-Opt.tail,1):t, [2 4])/cmperpix;
    y = R(max(t-Opt.tail,1):t, [3 5])/cmperpix;
    x = x(1) + range(x)/2;
    y = y(1) + range(y)/2;
    tmp = [x, y];
    addpoints(r, x, y);
    x = P(max(t-Opt.tail,1):t, 2)/cmperpix;
    y = P(max(t-Opt.tail,1):t, 3)/cmperpix;
    addpoints(p, x, y);
    tit.String = sprintf('frame=%d\n(Rx=%2.2f, Ry=%2.2f)\n(Px=%2.2f, Py=%2.2f)',t, x, y,tmp);
    drawnow

    if nargout > 0
        frames{t} = getframe(F);
    end

    pause(Opt.pause);
    clearpoints(p);
    clearpoints(r);
end
finished = true;

if nargout > 0
    varargout{1} = frames;
end

function frames = giveframe(i,animID,dayepoch,Opt)
    if Opt.preFetchFrames
        hash  = DataHash(struct('animID',animID,'dayepoch',Opt));
        hashfile = sprintf('/tmp/%s.mat');
        disp("Hashfile => " + hashfile);
        [frames, ~, cmperpix] = videoLib.framesFromInd(animal, dayepoch, 'all', 'resize',  Opt.resize);
        m = matfile(hashfile,'Writable',true);
        m.frames = frames;
    else
       frames = videoLib.framesFromInd(animID, dayepoch, i);
   end
