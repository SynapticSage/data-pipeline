function frame =  tail(animal, dayepoch, varargin)
% Returns the first frame for an animal for a day or dayepoch
frame  = videoLib.frameQuantile(animal, dayepoch, 1, varargin{:});
