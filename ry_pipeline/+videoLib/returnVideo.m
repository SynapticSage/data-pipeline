function OBJ = returnVideo(animal, day, epoch, varargin)

persistent cacheVideoFile;
persistent obj;

ip = inputParser;
ip.addOptional('kws',{});
ip.addOptional('persist',false);
ip.addOptional('close', false);
ip.parse(varargin{:})
Opt = ip.Results;
if Opt.close
    if ~isempty(cacheVideoFile)
        close(obj);  %  If it's persistent, then this is the flag that closes it
        fprintf('closing persisted video=%s\n', string(cacheVideoFile));
    else
        disp("nothing to close");
    end
    OBJ = [];
    return
end

animalInfo = animaldef(animal);
videoFile  = string(sprintf('%s/videos/%svideo%02d-%02d.mp4',...
    animalInfo{2:3}, day, epoch));

if Opt.persist && isequal(videoFile, cacheVideoFile) && ~isempty(obj)
    %disp('same')
    OBJ = obj;
elseif exist(videoFile,'file')
    %disp('new load')
    obj = VideoReader(videoFile, Opt.kws{:}); % Open new object
    cacheVideoFile = DataHash(char(videoFile));
    OBJ = obj;
else
    error("Video " + videoFile + " not found");
end
