addpath('/home/amirro/code/3rdparty/ImageNetToolboxV0.3');
addpath('/home/amirro/code/fragments');
baseFolder = '/home/amirro/data/image-net';
localFolder = baseFolder;

username = 'rosenfeld';
accesskey = '08ae62f4596102c760a629cc5dccecc861cf092b';
% wnid = 'n02992529'; % cellphone
% wnid = 'n02783161'; % ballpoint, pen...
% wnid = 'n02876657'; % bottle
% wnid = 'n04453156'; % toothbrush

wnids = {'n02992529','n02783161','n02876657','n04453156'};

% add code to the development kit...


for k = 4:length(wnids)
    wnid = wnids{k};
    
    
    recursiveFlag = false;
    
    if (~exist(localFolder,'dir'))
        mkdir(localFolder);
    end
    
    if (~exist(fullfile(localFolder,[wnid '.tar']),'file'))
        downloadImages(localFolder,username,accesskey,wnid,recursiveFlag);
        untar(fullfile(localFolder,[wnid '.tar']),...
            fullfile(localFolder,'Images'));
    end
end

%%
for k = 4:length(wnids) % read pascal records...
    wnid = wnids{k};     
    imageFolder = fullfile(localFolder,'Images');
    recordFolder = fullfile(localFolder,'Annotation',wnid);
    recs = dir(fullfile(recordFolder,'*.xml'));
    
    for iRec = 1:length(recs)
        clf;
        recFile = fullfile(recordFolder,recs(iRec).name);
        x=VOCreadxml(recFile);
        x = x.annotation;
        bboxes = [];
        objects = x.object;
        for iObj = 1:length(objects)
            obj = objects(iObj);
            b = obj.bndbox;
            bbox = str2num([b.xmin ' ' b.ymin ' ' b.xmax ' ' b.ymax]);
            bboxes = [bboxes;bbox];
        end
        
        bboxes = bboxes(:,[2 1 4 3]);
        
        
        imgFile = fullfile(imageFolder,[x.filename '.JPEG']);
        if (~exist(imgFile,'file'))
            warning([imgFile ' doesn''t exist']);
            continue;
        end
            
        imshow(imgFile);
        hold on;
        plotBoxes2(bboxes,'LineWidth',2,'Color','g');
        pause;
    end
end
