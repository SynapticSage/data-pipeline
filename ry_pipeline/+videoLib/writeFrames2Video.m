function writeFrames2Video(videoPath, frames, varargin)
% Shortcut for writing frames to a path
ip = inputParser;
ip.KeepUnmatched = true;
ip.addParameter('transform', []); % lambda to apply to each frame
ip.parse(varargin{:})
Opt = ip.Results;

unmatched = ip.Unmatched;

[path,file,ext] = fileparts(videoPath);
videoPath = string(path) + filesep + file + ".mp4";

V =  VideoWriter(videoPath);
for field = string(fieldnames(unmatched))'
    V.(field) = unmatched.(field);
end
V.open();
cleanup = onCleanup(@() V.close());
for f = progress(1:size(frames,4),'Title','Writing video...')
    if ~isempty(Opt.transform)
        V.writeVideo(Opt.transform(frames(:,:,:,f)));
    else
        V.writeVideo(frames(:,:,:,f));
    end

end
