function behaviorStruct = behaviorFromDio(animal, dayepoch)

animal = "RY7"
animalToPath(animal);
%animaldef_ = animaldef(animal);
%animalfolder = animaldef_{2};

day = dayepoch(1);
epoch = dayepoch(2);

load(sprintf('%sDIO%02d.mat',animal,day));
dio = DIO{day}{epoch};

% Let's spit out the whole thing into a table




