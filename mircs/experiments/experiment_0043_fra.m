%% experiment 0043 -
%% 29/6/2014
% same as 43 but using only the regions insize the face area.
addpath('/home/amirro/code/3rdparty/smallcode/');
addpath('/home/amirro/code/3rdparty/dsp-code');

default_init;
load fra_db;

%%
% prepare data...
all_class_names = {fra_db.class};
class_labels = [fra_db.classID];
classes = unique(class_labels);
% make sure class names corrsepond to labels....
[lia,lib] = ismember(classes,class_labels);
classNames = all_class_names(lib);
isTrain = [fra_db.isTrain];
load ~/storage/misc/drinking_params.mat;
theParams = optParams(1);
theParams.centerOnMouth = true;
[learnParams,conf] = getDefaultLearningParams(conf,1024);
featureExtractor = learnParams.featureExtractors{1}; % check this is indeed fisher
% featureExtractor.bowConf.bowmodel.numSpatialX = [1 2];
% featureExtractor.bowConf.bowmodel.numSpatialY = [1 2];
featureExtractor.bowConf.bowmodel.numSpatialX = [1];
featureExtractor.bowConf.bowmodel.numSpatialY = [1];

%%

% objTypes = {'head','hand','obj'};
objTypes = {'head','hand','obj','mouth'};
curParams = theParams;
curParams.featType = 'sift';
% curParams.objType = objTypes{iObjType};
curParams.max_nn_checks = 0;
curParams.sample_max = false;
curParams.wSize = [7 7];
curParams.cellSize = 4;
curParams.extent = 2;
%     curParams.extent = 1.5;
curParams.img_h = 70*curParams.extent/1.5;%
curParams.coarseToFine = true;
curParams.onlyObjectFeatures = false;
p = curParams;
p.extent = 2;
p.img_h = 70*p.extent/1.5;
p.coarseToFine = true;
specific_obj_params = {p,p,p,p};
share_across_classes = [false,true,true,false];
%TODO : make sure you're using the correct set of parameters,
%for iObjType = 1:length(objTypes)


for iObjType = 3 %1:length(objTypes)
    % add a detector for all images together.
    curParams = theParams;
    curParams.featType = 'sift';
    curParams.objType = objTypes{iObjType};
    curParams.max_nn_checks = 0;
    curParams.sample_max = false;
    curParams.wSize = [7 7]
    curParams.cellSize = 4;
    curParams.extent = 2;
    %     curParams.extent = 1.5;
    %curParams.img_h = 45*curParams.extent/1.5;% was 75 x % was 40....
    %     curParams.img_h = 60*curParams.extent/1.5;% was 75 x % was 40....
    curParams.coarseToFine = true;
    
    if (~isempty(specific_obj_params{iObjType}))
        curParams = specific_obj_params{iObjType};
        curParams.objType = objTypes{iObjType};
    end
    sel_test = ~isTrain & class_labels~=5;
    sel_train = isTrain & class_labels~=5;
    curParams.normalizeWithFace = false;
    curParams.centerOnMouth = true; %TODO
    %     curParams.img_h = 90*curParams.extent/1.5;%was 45, just for the nearest neighbors stuff
    curParams.onlyObjectFeatures = false;
    
    train_classes = [fra_db(isTrain).classID];
    train_imgs = {};
    for t = 1:length(fra_db)
        t
        if (fra_db(t).isTrain)
            [rois,roiBox,I] = get_rois_fra(conf,fra_db(t),roiParams);
            scaleFactor = 90*curParams.extent/1.5 /size(I,1);
            orig_size = size2(I);
            I = imResample(I,scaleFactor);
            train_imgs{t} = I;
        end
    end
    
    [XX,FF,offsets,all_scales,imgInds,subInds,values,kdtree,all_boxes,imgs,masks,origImgInds] = ...
        preparePredictionData_fra(conf,fra_db(sel_train),curParams);
    
    % extract features from objects only
    curParams.onlyObjectFeatures = true;
    [XX_obj,FF_obj,~,~,imgInds_obj,~,~,kdtree_obj,all_boxes_obj,imgs_obj,~,origImgInds_obj] = ...
        preparePredictionData_fra(conf,fra_db(sel_train(:)),curParams);
    
    %     origImgInds = cat(1,origImgInds{:});
    % fisher representations for all objects.
    
    rots = -1000*ones(size(masks));
    for t = 1:length(masks)
        t
        curMask = masks{t};
        if (nnz(curMask)==0)
            continue;
        end
        r = regionprops(curMask,'Orientation');
        r = r(1).Orientation;
        %                 curMask = imrotate(curMask,-r,'bilinear','crop');
        rots(t) = r;
        %                 clf;imagesc2(curMask*2+double(masks{t}));
        %                 pause(.01)
    end
    
    
    obj_fisher = {};
    newMasks = {};
    newImages = {};
    
    % create exemplar svms...
    
    
    %N = makeCluster;
    
    [z,ia,ib] = unique(imgInds);
    nn = origImgInds(ia);
    
    %     rots = rots*0;
    
    
    all_detectors = {};
    
    for t = 1:1:length(imgs)
        t
        
        sampleFactor = 1;
        if (rots(t)==-1000),continue,end
        curMask = masks{t};
        newMasks{t} = imrotate(curMask,-rots(t),'nearest','loose');
        curImg = imgs{t};
        newImages{t} = imrotate(curImg,-rots(t),'bilinear','loose');
        
        newImages{t} = imResample(newImages{t},sampleFactor,'bilinear');
        newMasks{t} = imResample(newMasks{t},sampleFactor,'nearest');
        %
        obj_fisher{t} = featureExtractor.extractFeatures(newImages{t}, newMasks{t},'normalization','Improved');
    end
    
    lengths = cellfun(@length,obj_fisher);
    empties = lengths < max(lengths);
    imgs_1 = newImages(~empties);
    masks_1 = newMasks(~empties);
    obj_fisher = cat(2,obj_fisher{~empties});
    
    %         P=pdist2(obj_fisher',obj_fisher','cosine');
    %         P=l2(obj_fisher',obj_fisher');
    %         figure,imagesc(P)
    %         [u,iu] = sort(P,2,'ascend');
    %%
    pp = randperm(length(imgs_1))
    %%
    %for q = 200:20:length(imgs_1)
    for ip  = 1:length(pp)
        q =pp(ip)
        knn = 5;
        curMask = imResample(masks_1{q},1,'nearest');
        curImg = imResample(imgs_1{q},1);
        wSize = 45;
        squarifyRegion  = true;
        if (squarifyRegion)
            regionBox = region2Box(curMask);
            regionBox = inflatebbox(regionBox,wSize*[1 1],'both',true);
            curMask = poly2mask2(box2Pts(regionBox),size2(curMask));
        end
        
        clf; vl_tightsubplot(1,2,1);
        displayRegions(curImg,curMask);
        %imagesc2(imgs_1{q});
        
        f = featureExtractor.extractFeatures(curImg, curMask,...
            'normalization', 'Improved');
        if (length(f)>1)
            P=pdist2(f',obj_fisher','cosine');
            [u,iu] = sort(P,2,'ascend');
            vl_tightsubplot(1,2,2); imagesc2(mImage(imgs_1(iu(2:knn+1))));
        else
            vl_tightsubplot(1,2,2); imagesc2(0);
        end
        pause
    end
    %%
    f_test = find(sel_test);
    %     f_test = find(~isTrain);
    debug_ = true;
    close all;
    debugParams.debug = true;
    debugParams.doVideo = false;
    debugParams.showFreq = 1;
    debugParams.pause = .5;
    curParams.nn = 10;
    curParams.max_nn_checks = curParams.nn*100;
    curParams.voteAll = true;
    debugParams.debug = true;
    curParams.nIter = 0;
    curParams.useSaliency = false;
    curParams.min_scale = 1;
    curParams.sample_max = false;
    
    for iClass = 1:length(classes)
        cls = iClass;
        curParams = theParams;
        curParams.featType = 'sift';
        curParams.objType = objTypes{iObjType};
        curParams.max_nn_checks = 0;
        curParams.sample_max = false;
        curParams.wSize = [7 7];
        curParams.cellSize = 4;
        curParams.extent = 3.5;
        %     curParams.extent = 1.5;
        curParams.img_h = 45*curParams.extent/1.5;% was 75 x % was 40....
        curParams.coarseToFine = true;
        
        if (~isempty(specific_obj_params{iObjType}))
            curParams = specific_obj_params{iObjType};
            curParams.objType = objTypes{iObjType};
        end
        sel_test = class_labels ==cls & ~isTrain;
        sel_train = class_labels ==cls & isTrain;
        curParams.normalizeWithFace = false;
        [XX,offsets,all_scales,imgInds,subInds,values,kdtree,all_boxes,imgs,masks] = ...
            preparePredictionData_fra(conf,fra_db(sel_train),curParams);
        f_test = find(sel_test);
        %     f_test = find(~isTrain);
        debug_ = true;
        close all;
        debugParams.debug = true;
        debugParams.doVideo = false;
        debugParams.showFreq = 1;
        debugParams.pause = .5;
        curParams.nn = 10;
        curParams.max_nn_checks = curParams.nn*100;
        curParams.voteAll = true;
        debugParams.debug = true;
        curParams.nIter = 0;
        curParams.useSaliency = false;
        curParams.min_scale = 1;
        curParams.sample_max = false;
        % find the
        %%
        close all
        debugParams.debug = false;
        toOverride = false;
        
        resDir_orig = '~/storage/s40_fra_box_pred_2014_09_17';
        resDir = '~/storage/s40_fra_box_pred_full';
        ensuredir(resDir);
        u = 0;
                
        load s40_fra; fra_db = s40_fra;
        
        for t = 1:length(fra_db)
            %             t = 885
            %
            %             if (~sel_test(t)),continue,end;
            %if (~fra_db(t).isTrain),continue;end
            
            if (~isempty(fra_db(t).indInFraDB))
                continue,
            end
            if (~fra_db(t).valid),continue,end
            %             if (fra_db(t).classID~=3),continue,end
            u = u+1;
            [iClass t u]
            %resPath = fullfile(resDir,[fra_db(t).imageID '_' classNames{iClass} '_' curParams.objType '.mat']);
            resPath = fullfile(resDir,[fra_db(t).imageID '_' curParams.objType '.mat']);
            %
            if (toOverride || ~exist(resPath,'file') || debugParams.debug)
                curParams.extent = 2;
                curParams.img_h = 70*curParams.extent/1.5;
                curParams.nn = 10; % was 10
                curParams.stepSize = 3;
                imgRots = -30:30:30;
                bestRot = 0;
                theRot = 0;
                maxScore = -inf;
                for flips = [0 1]
                    pp = zeros(size(imgRots));
                    for iRot = 1:length(imgRots)
                        curParams.rot =  imgRots(iRot);
                        curParams.flip = flips;
                        [pMap,I,roiBox,scaleFactor] = predictBoxes_fra(conf,fra_db(t),XX,curParams,offsets,all_scales,imgInds,subInds,values,imgs,masks,all_boxes,kdtree,origImgInds,debugParams);
                        u = max(pMap(:));
                        if (u > maxScore)
                            %                             u
                            maxScore = u;
                            bestFlip = flips;
                            bestRot = imgRots(iRot);
                        end
                    end
                end
                curParams.stepSize = 1;
                curParams.rot = bestRot;
                curParams.flip = bestFlip;
                %                     debugParams.rot = 0;
                [pMap,I,roiBox,scaleFactor,shapeMask] = predictBoxes_fra(conf,fra_db(t),XX,curParams,offsets,all_scales,imgInds,subInds,values,imgs,masks,all_boxes,kdtree,origImgInds,debugParams);
                if (curParams.flip)
                    I = flip_image(I);
                    pMap = flip_image(pMap);
                    shapeMask = flip_image(shapeMask);
                end
                I = imrotate(I,-bestRot,'bilinear','crop');
                pMap = imrotate(pMap,-bestRot,'bilinear','crop');
                shapeMask = imrotate(shapeMask,-bestRot,'bilinear','crop');
                if (debugParams.debug)
                    figure(1);clf;
                    vl_tightsubplot(2,2,2);
                    imagesc2(sc(cat(3,pMap.^2,I),'prob_jet'));
                    boxes = pMapToBoxes(pMap,20,3);plotBoxes(boxes);
                    vl_tightsubplot(2,2,1);
                    imagesc2(I);%;plotBoxes(boxes);
                    %vl_tightsubplot(1,3,3); imagesc2(sc(cat(3,shapeMask.^2,I),'prob_jet'));
                    vl_tightsubplot(2,2,3); imagesc2(sc(cat(3,shapeMask.^2,I),'prob_jet'));
                    II = getImage(conf,fra_db(t));
                    boxes_orig = boxes/scaleFactor+repmat([roiBox([1 2 1 2]) 0],size(boxes,1),1);
                    %                             figure(2),clf;imagesc2(II);
                    %                             plotBoxes(boxes_orig);
                    pause;drawnow
                    
                else
                    %                     if (~exist(resPath,'file'))
                    %                     [pMap,I,roiBox,scaleFactor] = predictBoxes_fra(conf,fra_db(t),XX,curParams,offsets,all_scales,imgInds,subInds,values,imgs,masks,all_boxes,kdtree,debugParams);
                    %             size2(I)
                    %             figure(1);clf;imagesc2(sc(cat(3,pMap,I),'prob_jet'));
                    boxes = pMapToBoxes(pMap,20,3);
                    %plotBoxes(boxes);
                    %             II = getImage(conf,fra_db(t));
                    boxes_orig = boxes/scaleFactor+repmat([roiBox([1 2 1 2]) 0],size(boxes,1),1);
                    save(resPath,'pMap','shapeMask','roiBox','scaleFactor','boxes','boxes_orig');
                    %                     end
                end
                
            end
        end
    end
    
    
    %%