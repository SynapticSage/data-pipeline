P = ndb.load('RY16','pos','indices',[36 2]);
P = ffend(P);
R = ndb.load('RY16','rawpos','indices',[36 2]);
R = ffend(P);

P.data = P.data/P.cmperpixel;
R.data = R.data/R.cmperpixel;
R.pos = [R.data(:,2)+(R(:,4)-R(:,2))/2, ...
         R.data(:,3)+(R(:,5)-R(:,3))/2];
Rp = R.pos;
Pd = P.data;

frame = videoLib.head('RY16',[36 2]);
figure;
imagesc(frame);
a = animatedline;
b = animatedline;
set([a,b], 'MarkerSize', 10, 'MarkerFill', 'none');
set(a, 'Color', 'white');
set(b, 'Color', 'red');
N = size(R.data,1);

% Demonstrate issues with point inaccuracies
for i = progress(1:N)
    addpoints(a, Rp(max(1,i-tail):i,2), Rp(max(1,i-tail):i,3));
    addpoints(b, Pd(max(1,i-tail):i,2), Pd(max(1,i-tail):i,3));
    pause(delta);
    clearpoints(a);
    clearpoints(b);
end
