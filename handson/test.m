addpath('/home/amirro/code/utils');
addpath('/home/amirro/code/3rdparty/voc-release4.01');
inputDir = '/home/amirro/data/Stanford40';
xmlDir = fullfile(inputDir,'XMLAnnotations');
imgDir = fullfile(inputDir,'JPEGImages');
actionsFileName = fullfile(inputDir,'ImageSplits/actions.txt');
[A,ii] = textread(actionsFileName,'%s %s');
f = fopen(actionsFileName);
A = A(2:end);

action_choice = 1;
chosen_action = A{action_choice};

chosen_action = 'drinking';

load(fullfile(inputDir,'MatlabAnnotations',...
    ['annotation_' chosen_action]));


%%
close all;
for k = 1:length(annotation)
    curAnno = annotation{k};
    imgFile = fullfile(imgDir, curAnno.imageName);
    clf;
    imshow(imgFile);
    hold on;
    plotBoxes2(curAnno.bbox(:,[2 1 4 3]),'Color','g');
    pause;    
end



