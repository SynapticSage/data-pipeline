function positionGrid(animID, dayepoch, gridTable)
% TODO this was an early function FIXME
%
% It's realization doesn't follow the format of an atom
%
% plots position grid

frame = videoLib.head(animID, dayepoch);
imagesc(frame);
[~,cmperpix] = videoLib.frameDat(animID, dayepoch(1));
colors = cmocean('phase',6);

for row = 1:height(gridTable)
    rect = gridTable(row,["left","down","right","up"]);
    rect = table2array(rect)/cmperpix;
    rect(3) = rect(3)-rect(1);
    rect(4) = rect(4)-rect(2);
    if gridTable.wellZone(row)
        label = "Well " + gridTable.well(row);
        if label == "Well 5"
            label = "Home";
        end
        drawrectangle('Color', colors(gridTable.well(row),:),  'Position', rect, 'FaceAlpha', 0.2, 'DrawingArea', rect, 'InteractionsAllowed', 'none','Label',label)
    else
        drawrectangle('Color', [1 1 1],  'Position', rect, 'FaceAlpha', 0.1, 'DrawingArea', rect, 'InteractionsAllowed','none')
    end
end
