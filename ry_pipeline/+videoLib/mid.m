function frame =  mid(animal, dayepoch, varargin)
% Returns the first frame for an animal for a day or dayepoch
frame  = videoLib.frameQuantile(animal, dayepoch, 0.5, varargin{:});
