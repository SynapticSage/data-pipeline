function Tet =  ry_ml_tetoption(areas, tetrodePerArea, varargin)

ip = inputParser;
ip.addParameter('freq_min', []); % list of freqMin per area
ip.addParameter('freq_max', []); % list of freqMin per area
ip.parse(varargin{:})
Opt = ip.Results;

if isempty(Opt.freq_min)
    i = 0;
    for area = areas
        i = i + 1;
        if contains(lower(area), ["pfc","ofc"])
            Opt.freq_min(i) = 300;
        elseif any(contains(lower(area), ["hpc" "ca1","superdead"]))
            Opt.freq_min(i) = 600;
        else
            error("Please provide freq_min")
        end
    end
end

if isempty(Opt.freq_max)
    i = 0;
    for area = areas
        i = i + 1;
        if contains(lower(area), ["pfc", "ofc"])
            Opt.freq_max(i) = 6000;
        elseif any(contains(lower(area), ["hpc", "ca1","superdead"]))
            Opt.freq_max(i) = 6000;
        else
            error("Please provide freq_max")
        end
    end
end

Tet = struct('freq_min',[],'freq_max', [], 'area', [], 'tetrode', []);
Tet = repmat(Tet, 1, max(cellfun(@max, tetrodePerArea)));
for a = 1:numel(areas)
    for tetrode = tetrodePerArea{a}
        %if tetrode==10;keyboard;end
        Tet(tetrode).freq_min = Opt.freq_min(a);
        Tet(tetrode).freq_max = Opt.freq_max(a);
        Tet(tetrode).tetrode = tetrode;
        Tet(tetrode).area = areas(a);
    end
end

for tetrode = 1:numel(Tet)
        assert(numel(Tet(tetrode).freq_max) <= 1)
        assert(numel(Tet(tetrode).freq_min) <= 1)
end
