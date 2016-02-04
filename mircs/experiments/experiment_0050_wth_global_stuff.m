

%% 21/09/2014
% tell apart action classes by close inspection of the relevant segments.
% now we have for each image it's
% 1. location of face
% 2. facial landmarks
% 3. segmentation
% 4. saliency
% 5. location of action object (pixel-wise mask)
% 6. prediction of location of action object, learned separately.
if (~exist('initialized','var'))
    initpath;
    config;
    conf.get_full_image = true;
    [learnParams,conf] = getDefaultLearningParams(conf,1024);
    load fra_db.mat;
    all_class_names = {fra_db.class};
    class_labels = [fra_db.classID];
    classes = unique(class_labels);
    % make sure class names corrsepond to labels....
    [lia,lib] = ismember(classes,class_labels);
    classNames = all_class_names(lib);
    isTrain = [fra_db.isTrain];
    normalizations = {'none','Normalized','SquareRoot','Improved'};
    %     addpath('/home/amirro/code/3rdparty/logsample/');
    addpath(genpath('/home/amirro/code/3rdparty/MCG-PreTrained/MCG-PreTrained'));install
    addpath(genpath('/home/amirro/code/3rdparty/cvpr14_saliency_code'));
%     rmpath(genpath('/home/amirro/code/3rdparty/attribute_code'));
    addpath(genpath('/home/amirro/code/3rdparty/seg_transfer'));
    % for edge boxes
    model.opts.multiscale=0; model.opts.sharpen=2; model.opts.nThreads=4;
    [learnParams,conf] = getDefaultLearningParams(conf,256);
    featureExtractor = learnParams.featureExtractors{1};
    featureExtractor.bowConf.featArgs = {'Step',1};
    featureExtractor.bowConf.bowmodel.numSpatialX = [1 2];
    featureExtractor.bowConf.bowmodel.numSpatialY = [1 2];
    initialized = true;
    conf.get_full_image = true;
    load ~/code/mircs/s40_fra_faces_d.mat
    load s40_fra
    s40_fra_orig = s40_fra_faces_d
    params.requiredKeypoints = {'LeftEyeCenter','RightEyeCenter','MouthCenter','MouthLeftCorner','MouthRightCorner','ChinCenter','NoseCenter'};
    load('allPtsNames','allPtsNames');
    [~,~,reqKeyPointInds] = intersect(params.requiredKeypoints,allPtsNames);
    fra_db = s40_fra;
    net = init_nn_network();    
    nImages = length(s40_fra);
    top_face_scores = zeros(nImages,1);
    for t = 1:nImages
        top_face_scores(t) = max(s40_fra(t).raw_faceDetections.boxes(:,end));
    end
    min_face_score = 0;
    img_sel_score = col(top_face_scores > min_face_score);
%     img_sel_score = find(img_sel_score);
    fra_db = s40_fra(img_sel_score);
    top_face_scores_sel = top_face_scores(img_sel_score);
end

%% initialize parameters for different feature types.
params = defaultPipelineParams();
%%
train_set = find([fra_db.isTrain]);
train_set = train_set(1:2:end);
test_set = find(~[fra_db.isTrain]);
val_set = setdiff(find([fra_db.isTrain]),train_set);

%%
% aggregate features and labels, from valid images only, for now
% valids = {};
% u = {};
% validImages = cellfun(@(x) x.valid,all_train_feats);
% train a set of classifiers
clear stage_params
stage_params(1)= defaultPipelineParams();
stage_params(1).learning.classifierType = 'svm';
stage_params(1).learning.classifierParams.useKerMap = false;
dataDir = '~/storage/s40_fra_feature_pipeline_all';
stage_params(1).dataDir = dataDir;
% [labels,features,ovps] = collectFeatures(conf,all_train_feats,stage_params(1).params.features);
classes = [conf.class_enum.DRINKING conf.class_enum.SMOKING conf.class_enum.BLOWING_BUBBLES conf.class_enum.BRUSHING_TEETH];
top_k_false = 100;
sets = {train_set,val_set};
% set_results = {};
classifiers = {};
curParams = stage_params(1);
ind_in_orig = {};
debugging = false;
clear all_results;

imageLevelFeaturesPath = '~/storage/misc/imageLevelFeatures.mat';
if (exist(imageLevelFeaturesPath,'file'))
    load(imageLevelFeaturesPath);
else
    imageLevelFeatures = {};
    for t = 1:length(fra_db)
        t
        load(j2m('~/storage/s40_fra_feature_pipeline_partial_dnn_6_7',fra_db(t)),'moreData');
        imageLevelFeatures{t} = moreData.face_feats;
    end
    imageLevelFeatures = cat(2,imageLevelFeatures{:});
    save(imageLevelFeaturesPath,'imageLevelFeatures');
end

debugging = true;
stage1ClassifierPath = '~/storage/misc/stage_1_classifier.mat';
% "light" features for entire train set,
stage_1_feats_path = '~/storage/misc/stage_1_train_feats.mat';
if (exist(stage_1_feats_path,'file'))
    load(stage_1_feats_path);
else
    [feats1,labels1,ovps1] = collect_feature_subset(fra_db([fra_db.isTrain]),curParams);
    save(stage_1_feats_path,'feats1','labels1','ovps1');
end
[curFeats2,curLabels2,ovps2] = collect_feature_subset(fra_db(train_set),curParams);
classifierBaseDir = '~/storage/classifiers/stage1';ensuredir(classifierBaseDir);

for iSet = 1:length(sets)
    curTrainSet = sets{iSet};
    curValSet = sets{2-iSet+1};
    if (debugging)
        curTrainSet = curTrainSet(1:5:end);
        curValSet = curValSet(1:5:end);
    end
    
    classifier_1_data = struct('feats',{},'labels',{});
    
    classifier_data = makeClassifierSet(fra_db,curTrainSet,curValSet,curParams,classes);
end
for iSet = 1:length(sets)
    curTrainSet = sets{iSet};
    curValSet = sets{2-iSet+1};
    if (debugging)
        curTrainSet = curTrainSet(1:5:end);
        curValSet = curValSet(1:5:end);
    end
    classifier_data = makeClassifierSet(fra_db,curTrainSet,curValSet,curParams,classes);
end

region_classifier_data_path = '~/storage/misc/region_classifiers.mat';
if (exist(region_classifier_data_path,'file'))
    load(region_classifier_data_path)
else
    debugging = false;
%     classifier_data = struct('iSet',{},'trainInds',{},'valInds',{},'classifiers',{},'val_results',{});
    
    for iSet = 1:length(sets)
        curTrainSet = sets{iSet};
        curValSet = sets{2-iSet+1};
        if (debugging)
            curTrainSet = curTrainSet(1:5:end);
            curValSet = curValSet(1:5:end);
        end        
        classifier_data = makeClassifierSet(fra_db,curTrainSet,curValSet,curParams,classes);
    end
    save(region_classifier_data_path,'classifier_data');
end

% train an overall region classifier

stage_1_boosting = stage_params(1);
stage_1_boosting.learning.classifierType = 'boosting';
stage_1_svm = stage_params(1);
stage_1_svm.learning.classifierType = 'svm';
stage_1_svm.learning.classifierParams.useKerMap = true;

boosting_region_classifier = makeClassifierSet(fra_db,find([fra_db.isTrain]),find(~[fra_db.isTrain]),stage_1_boosting,classes);
svm_region_classifier = makeClassifierSet(fra_db,find([fra_db.isTrain]),find(~[fra_db.isTrain]),stage_1_svm,classes);
stage_params_everything = defaultPipelineParams(true);
stage_params_everything.features.getAppearanceDNN = true;
stage_params_everything.features.getHOGShape = false;
stage_params_everything.dataDir = '~/storage/s40_fra_feature_pipeline_all_everything';
stage_params_everything.learning.classifierType = 'svm';
stage_params_everything.learning.classifierParams.useKerMap = true;

svm_region_classifier_everything = makeClassifierSet(fra_db,find([fra_db.isTrain]),find(~[fra_db.isTrain]),stage_params_everything,classes);


% now retain only the top few regions from each of the valitation results,
stage_1_res_dir = '~/storage/stage_1_subsets';
top_k_false = 100;
for ii = 1:length(classifier_data)
    prepareForNextStage(classifier_data(ii).val_results,...
        fra_db(classifier_data(ii).valInds),...
        stage_params(1).dataDir,...
        stage_1_res_dir,stage_params(1),top_k_false);
end

kk = findImageIndex(fra_db,'drinking_053.jpg');
kk = findImageIndex(fra_db,'smoking_213.jpg');
%[curFeats,curLabels] = collect_feature_subset(fra_db(k),stage_params(1));
v_results = applyToImageSet(conf,fra_db(k),classifiers,stage_params(1));
% set state 2 parameters
stage_params(2) = stage_params(1);
stage_params(2).features.getHOGShape = true;
stage_params(2).features.getAppearanceDNN = true;
stage_params(2).prevStageDir = '~/storage/stage_1_subsets';
stage_params(2).features.dnn_net = init_nn_network();
stage_params_dummy = stage_params(1);
extract_all_features(conf,fra_db(kk),stage_params_dummy);

%% extract dnn features only...
stage_params(2) = resetFeatures(stage_params(2),true);%resetFeatures(stage_params(2),false);
stage_params(2).features.getBoxFeats = 0;
stage_params(2).features.getAppearanceDNN = true;
stage_params(2).dataDir = '~/storage/s40_fra_feature_pipeline_stage_2';
stage_params(2).learning.classifierType = 'svm';
stage_params(2).learning.classifierParams.useKerMap = false;
my_train_set = train_set;
my_val_set = val_set;
region_classifier_data_path_2 = '~/storage/misc/region_classifiers_2.mat';
if (exist(region_classifier_data_path_2,'file'))
    load(region_classifier_data_path_2)
else
    stage_2_classifiers = {};
    stage_2_classifiers{1} = makeClassifierSet(fra_db,my_train_set,my_val_set,stage_params(2),classes);
    stage_2_classifiers{2} = makeClassifierSet(fra_db,my_val_set,my_train_set,stage_params(2),classes);
    save(region_classifier_data_path_2,'stage_2_classifiers');
end

% show results...
curRes = stage_2_classifiers{1};
[imgInds,scores] = summarizeResults(curRes);
[u,iu] = sort(scores,2,'descend');
displayImageSeries(conf,fra_db(imgInds(iu(2,:))));
iu1 = iu(2,:);
%%
for t = 1:length(curRes.valInds)
    
    imgInd = curRes.valInds(iu1(t));
%     k = iu1(t);
    curImgData =  switchToGroundTruth(fra_db(imgInd));
    if (curImgData.classID~=classes(2)),continue,end
    t
%     break
    disp(['face score = ' num2str(curImgData.raw_faceDetections.boxes(1,end))]);
%     if (fra_db(imgInd).classID~=9),continue,end
    resPath = j2m('~/storage/s40_fra_feature_pipeline_partial_dnn_6_7',curImgData);
    L = load(resPath,'feats','moreData','selected_regions');
    [rois,roiBox,I,scaleFactor,roiParams] = get_rois_fra(conf,curImgData,stage_params.roiParams); 
    iobj = find(strcmp({rois.name},'obj'))
    if none(iObj),continue,end
    rr = poly2mask2(rois(iobj).poly,size2(I)); 
    
    [ovps,ints,uns] = regionsOverlap({rr}, L.selected_regions);
    
    displayRegions(I,L.selected_regions,ovps,0,5);
    continue
    
    lm = loadDetectedLandmarks(conf,curImgData);
    lm = transformToLocalImageCoordinates(lm(:,1:4),scaleFactor,roiBox);
    moreFun = @(x) plotPolygons(boxCenters(lm),'g.','LineWidth',2);
    decision_values = curRes.val_results(iu1(t)).decision_values;
    clf;imagesc2(I); plotPolygons(boxCenters(lm),'g.','LineWidth',2); pause;
    displayRegions(I,L.selected_regions,decision_values(1,:),0,5);
    
    
    
%     displayRegions(I,L.selected_regions); 
end

%% the everything-based-classifier...
total_params = defaultPipelineParams(true);
total_params.features.getAppearanceDNN = true;
total_params.features.getHOGShape = true;
total_params.dataDir = '~/storage/s40_fra_feature_pipeline_all_everything';
total_params.learning.classifierType = 'rand_forest';
total_params.learning.classifierParams.useKerMap = false;

train_indices = find([fra_db.isTrain]);
test_indices = find(~[fra_db.isTrain]);
% train_indices = train_indices(1:100:end);
% test_indices = test_indices(1:100:end);

% tried with random forest, didn't really work, trying svm + homkermap
total_params.learning.classifierType = 'svm';
total_params.learning.classifierParams.useKerMap = false;
maxNegFeats = 10;
classifier_all = makeClassifierSet(fra_db,train_indices,test_indices,total_params,classes,[],maxNegFeats)
save classifier_all classifier_all


classifiers = [classifiers{:}];
classifier_all = makeClassifierSet(fra_db,train_indices,test_indices,total_params,classes,classifiers);
save classifier_all classifier_all
% 
% theClassifiers = struct('tdata',{});
% for iClass = 1:length(classes)
%     theClassifiers(iClass).tdata = classifier_all.classifiers(:,iClass);
% end
classifier_all_corrected = makeClassifierSet(fra_db,train_indices,test_indices,total_params,classes,theClassifiers);
save classifier_all_corrected classifier_all_corrected

applyToImageSet(fra_db(test_set),classifier_all,total_params);

save classifier_all classifier_all
% (run in parallel)
%% train a region based classifier on appearance
all_train_set = [fra_db.isTrain];
curParams = stage_params(2);
stage_params(2).dataDir = '~/storage/s40_fra_feature_pipeline_stage_2';
[curFeats,curLabels] = collect_feature_subset(fra_db(all_train_set(1:10)),curParams);
%classifiers{iSet} = train_region_classifier(conf,curFeats,curLabels,curClass,curParams);
stage_2_classifiers = {};
for iClass = 1:length(classes)
    classifiers{iClass} = train_region_classifier(conf,curFeats,curLabels,classes(iClass),curParams);
end

%classifier_data(iSet).val_results = applyToImageSet(conf,fra_db(curValSet),classifiers,curParams);

% region_classifiers_all = {};
% [curFeats,curLabels] = collect_feature_subset(fra_db(curTrainSet),curParams);    
% for iSet = 1
%     curTrainSet = sets{iSet};
%     curValSet = sets{2-iSet+1};    
%     [curFeats,curLabels] = collect_feature_subset(fra_db(curTrainSet),curParams);    
%     classifiers{iSet} = train_region_classifier(conf,curFeats,curLabels,curClass,curParams);                
% end
regional_test_results = applyToImageSet(conf,fra_db(test_set),classifiers{1},curParams);

%%
test_scores_region_2 = zeros(4,length(regional_test_results));
for t = 1:length(test_set)
    test_scores_region_2(:,t) = max(boosting_region_classifier.val_results(t).decision_values,[],2);
end

test_scores_region_svm = zeros(4,length(regional_test_results));
for t = 1:length(test_set)
    test_scores_region_svm(:,t) = max(svm_region_classifier.val_results(t).decision_values,[],2);
end

test_scores_region_all = zeros(4,length(classifier_all.val_results));
for t = 1:length(test_set)
    test_scores_region_all(:,t) = max(classifier_all.val_results(t).decision_values,[],2);
end
%%
AA  =load('~/storage/misc/all_s40_dnn_m_2028');
% all_s40_dnn = all_s40_dnn_verydeep;
% 
all_s40_dnn = AA.all_s40_dnn_m_2048;
myNormalizeFun = @(x) normalize_vec(x);
% myNormalizeFun  = @(x) x;
%%
global_feats = myNormalizeFun([all_s40_dnn.full_feat]); % entire image
global_feats_sel = global_feats(:,img_sel_score); % entire image, selection by score
crop_feats = myNormalizeFun([all_s40_dnn.crop_feat]); % cropped image
crop_feats_sel = crop_feats(:,img_sel_score); % cropped image, selection by score
feats_face = myNormalizeFun([imageLevelFeatures.global_17]); % face features (selection)
feats_mouth = myNormalizeFun([imageLevelFeatures.mouth_17]); % mouth features (selection)
%%
clear perf_crop perf_global perf_no_global perf_all
% feats_test_face = feat_face(:,all_test);
% ([imageLevelFeatures(all_test).global]);
% feats_test_crop = (crop_feats_sel(:,all_test));
% feats_test_global = global_feats_sel(:,all_test);
results_with_global = {};
results_no_global = {};
%%
%%
for iClass = 1%:4
    curClass = classes(iClass);
    all_test = find(~[fra_db.isTrain]);        
%     curClass = conf.class_enum.READING;    
    % find the optimal weight....
    classifier_face = train_classifier_helper(fra_db,feats_face,curClass);
    classifier_mouth = train_classifier_helper(fra_db,feats_mouth,curClass);
    classifier_global = train_classifier_helper(s40_fra,global_feats,curClass);
    classifier_crop = train_classifier_helper(s40_fra,crop_feats,curClass);
    %
    test_res_face = classifier_face.w(1:end-1)'*(feats_face(:,all_test));
    test_res_mouth = classifier_mouth.w(1:end-1)'*(feats_mouth(:,all_test));
    test_res_global = classifier_global.w(1:end-1)'*global_feats_sel(:,all_test);
    test_res_crop = classifier_crop.w(1:end-1)'*crop_feats_sel(:,all_test);           

    orig_test = ~[s40_fra.isTrain];
    orig_labels = [s40_fra.classID];
    orig_labels = 2*(orig_labels==curClass)-1;
    
    orig_scores = -100*ones(size(s40_fra));
    orig_scores = orig_scores + rand(size(orig_scores ));
    
    totalScores_no_global = 1*test_res_face+.5*test_res_mouth+.5*test_scores_region_all(iClass,:);
    results_no_global{iClass} = totalScores_no_global;        
    
    orig_scores([fra_db(all_test).imgIndex]) = totalScores_no_global;
    [perf_no_global(iClass).recall, perf_no_global(iClass).precision, perf_no_global(iClass).info] = ...
        vl_pr(orig_labels(orig_test),orig_scores(orig_test));
    
    orig_scores([fra_db(all_test).imgIndex]) = 1*test_res_global;
    [perf_global(iClass).recall, perf_global(iClass).precision, perf_global(iClass).info] = ...
        vl_pr(orig_labels(orig_test),orig_scores(orig_test));
    
    orig_scores([fra_db(all_test).imgIndex]) = 1*test_res_crop;
    [perf_crop(iClass).recall, perf_crop(iClass).precision, perf_crop(iClass).info] = ...
        vl_pr(orig_labels(orig_test),orig_scores(orig_test));
    
    orig_scores([fra_db(all_test).imgIndex]) = totalScores_no_global+test_res_crop;
    [perf_and_crop(iClass).recall, perf_and_crop(iClass).precision, perf_and_crop(iClass).info] = ...
        vl_pr(orig_labels(orig_test),orig_scores(orig_test));
    
    results_with_global{iClass} = totalScores_no_global+test_res_global;
    orig_scores([fra_db(all_test).imgIndex]) = totalScores_no_global+test_res_global;
    [perf_and_global(iClass).recall, perf_and_global(iClass).precision, perf_and_global(iClass).info] = ...
        vl_pr(orig_labels(orig_test),orig_scores(orig_test));
    
    orig_scores([fra_db(all_test).imgIndex]) = totalScores_no_global+test_res_global+test_res_crop;
    [perf_and_crop_and_global(iClass).recall, perf_and_crop_and_global(iClass).precision, perf_and_crop_and_global(iClass).info] = ...
        vl_pr(orig_labels(orig_test),orig_scores(orig_test));
        
%     totalScores = test_res_global;
%     totalScores = test_res_face+.5*test_res_mouth;
%    curClass = classes(iClass)
%     totalScores = test_scores_region_all(iClass,:);    
    
    vl_pr(orig_labels(orig_test),orig_scores(orig_test));
    all_labels = 2*([fra_db(all_test).classID]==curClass)-1;    
end
%%

%%
infos_global = [perf_global.info];
infos_crop = [perf_crop.info];
infos_no_global = [perf_no_global.info]
infos_with_crop = [perf_and_crop.info];
infos_with_global = [perf_and_global.info];
infos_with_all = [perf_and_crop_and_global.info];

ap_infos_global = [infos_global.ap] 
ap_infos_crop = [infos_crop.ap]
ap_infos_no_global = [infos_no_global.ap]
ap_infos_with_crop = [infos_with_crop.ap]
ap_infos_with_global = [infos_with_global.ap]
ap_infos_with_all = [infos_with_all.ap]

% gt_labels = 2*([fra_db(all_test).classID]==curClass)-1;
% vl_pr(gt_labels,test_res_mouth+test_res_face);
%%

%%
[u,iu] = sort(orig_scores,'descend');
for t = 1:length(u)
    k = iu(t);
    [I,I_rect] = getImage(conf,s40_fra(k));
    clf; imagesc2(I);     
    plotBoxes(bsxfun(@plus,s40_fra(k).raw_faceDetections.boxes(:,1:4),I_rect([1 2 1 2])),'r--','LineWidth',2);
    plotBoxes(s40_fra(k).faceBox);
%     plotBoxes(bsxfun(@plus,s40_fra(k).raw_faceDetections.boxes(:,1:4),I_rect),'r--','LineWidth',2);
    pause
end
%%
% prepare stage 1 results for feature calculation
stage_1_res_dir = '~/storage/stage_1_subsets';
top_k_false = 20;
prepareForNextStage(all_results,fra_db,stage_params(1).dataDir,stage_1_res_dir,stage_params(1),top_k_false)
% calculate...
% collect results for training data
stage2Dir = '~/storage/s40_fra_feature_pipeline_stage_2';
stage_params(2) = stage_params(1);
stage_params(2).dataDir = stage2Dir;
stage_params(2) = resetFeatures(stage_params(2),false);
stage_params(2).features.getAttributeFeats = true;
stage_params(2).learning.classifierType = 'rand_forest';
[curFeats,curLabels] = collect_feature_subset(fra_db([train_set val_set]),stage_params(2));
nans = any(isnan(curFeats),1);
% train a classifer with all features involved
[posFeats,negFeats] = splitFeats(curFeats(:,~nans),curLabels(~nans)==curClass);

normalizeFeats = false;
% stage_params(2).learning.classifierType = 'boosting';
stage_2_classifier = train_region_classifier(conf,curFeats,curLabels,curClass,stage_params(2));

% collect features, apply classifier
% [curFeats,curLabels] = collect_feature_subset(fra_db(test_set),curParams);
% prepare stage 1 results for feature calculation on test images
test_results_1 = applyToImageSet(conf,fra_db(test_set),classifiers{1},curParams);
prepareForNextStage(test_results_1,fra_db(test_set),stage_params(1).dataDir,stage_1_res_dir,valParams,top_k_false)
% ....run calculation...

% run on test images as well...
% all_results = cat(2,set_results{:});
%%
stage2Dir = '~/storage/s40_fra_feature_pipeline_stage_2';
%[feats,labels] = loadStageResults(conf,all_results,fra_db,stage2Dir);
stage_params(2).dataDir = stage2Dir;
stage_params(2) = stage_params(1);
stage_params(2).features.getAppearance = true;
max_neg_to_keep = 30;
[curFeats,curLabels] = collect_feature_subset(fra_db([train_set val_set]),stage_params(2),max_neg_to_keep);
classifier_2 = train_region_classifier(conf,curFeats,curLabels,curClass,stage_params(2))
% collect some results from the
test_subset = ~[fra_db.isTrain] & [fra_db.classID]==9;
test_results = applyToImageSet(conf,fra_db(test_set),classifier_2,stage_params(2));

%%
%%



for iClass = 1:4
    totalScores_no_global = results_with_global{iClass};
    [z,iz] = sort(totalScores_no_global,'descend');
    test_set_results = {};
    for u = 1:20%length(test_set)
        u
        max_neg_to_keep = inf;
        k = test_set(iz(u))
        %         if (fra_db(k).classID~=classes(4)),continue,end
        outPathChosen = fullfile('/home/amirro/notes/images/cvpr_2015/interpretation_chosen',strrep(fra_db(k).imageID,'.jpg','.png'));
        if (~exist(outPathChosen,'file')),continue,end
        resPath1 = j2m(total_params.dataDir,fra_db(k));
        L = load(resPath1,'feats','moreData','selected_regions');
        %     [featStruct.feats,featStruct.moreData,selected_regions] = extract_all_features(conf,fra_db(k),...
        %         stag[rois,roiBox,I,scaleFactor,roiParams] = get_rois_fra(conf,fra_db(k),params.roiParams);
        
        [labels, features,all_ovps,is_gt_region,orig_inds] = collectFeatures(L, total_params.features);
        %load(resPath,'feats','moreData','masks'); % don't need the segmentation here...
        %     [curFeats,curLabels] = collect_feature_subset(fra_db(k),stage_params(2),max_neg_to_keep);
        
        f = apply_region_classifier(classifier_all.classifiers(iClass),features,total_params);
        [rois,roiBox,I,scaleFactor,roiParams] = get_rois_fra(conf,fra_db(k),params.roiParams);
        f(isnan(f)) = -inf;
        q = displayRegions(I,L.selected_regions,f,-1,1);        
        imwrite(q,outPathChosen);
        
        %     pause        
    end
end

%%

m = -inf(size(fra_db));
f = find(~isTrain);
for t = 1:length(test_set)
    m(f(t)) = max(test_set_results{f(t)});
end

figure,vl_pr(2*([fra_db(~isTrain).classID]==curClass)-1,m(~isTrain));
[z,iz] = sort(m(~isTrain),'descend');
for r = 1:length(test_set)
    max_neg_to_keep = inf;
    k = test_set(iz(r));
    %     if (fra_db(k).classID~=9),continue,end
    resPath1 = j2m(stage_params(1).dataDir,fra_db(k));
    
    [rois,roiBox,I,scaleFactor,roiParams] = get_rois_fra(conf,fra_db(k),params.roiParams);
    clf; imagesc2(I); title(num2str(z(r)));pause;continue
    
    L = load(resPath1);
    %     [featStruct.feats,featStruct.moreData,selected_regions] = extract_all_features(conf,fra_db(k),...
    %         stage_params(2),L.moreData,L.selected_regions);
    [labels, features,all_ovps,is_gt_region,orig_inds] = collectFeatures(L,stage_params(1).features);
    %load(resPath,'feats','moreData','masks'); % don't need the segmentation here...
    %     [curFeats,curLabels] = collect_feature_subset(fra_db(k),stage_params(2),max_neg_to_keep);
    f = apply_region_classifier(classifiers{1},features,stage_params(1))+...
        apply_region_classifier(classifiers{2},features,stage_params(1));
    
end

test_set_results = {};
%%
for u = 1:length(test_set)
    max_neg_to_keep = inf;
    k = test_set(u);
    if (fra_db(k).classID~=9),continue,end
    resPath1 = j2m(stage_params(1).dataDir,fra_db(k));
    L = load(resPath1);
    %     [featStruct.feats,featStruct.moreData,selected_regions] = extract_all_features(conf,fra_db(k),...
    %         stage_params(2),L.moreData,L.selected_regions);
    
    stage_params_everything
    [labels, features,all_ovps,is_gt_region,orig_inds] = collectFeatures(L,stage_params(1).features);
    %load(resPath,'feats','moreData','masks'); % don't need the segmentation here...
    %     [curFeats,curLabels] = collect_feature_subset(fra_db(k),stage_params(2),max_neg_to_keep);
    f = apply_region_classifier(classifiers{1},features,stage_params(1))+...
        apply_region_classifier(classifiers{2},features,stage_params(1));
    [rois,roiBox,I,scaleFactor,roiParams] = get_rois_fra(conf,fra_db(k),params.roiParams);
    
    % end
    %     clf;
    %     disp('stage 1');
    %     displayRegions(I,L.selected_regions,f,0,1);continue
    % continue;
    %     break
    [u,iu] = sort(f,'descend');
    selected_regions = L.selected_regions(iu(1:100));
    u = u(1:5);
    stage_params(2).get_gt_regions = false;
    [featStruct.feats,featStruct.moreData,selected_regions] = ...
        extract_all_features(conf,fra_db(k),stage_params(2),L.moreData,selected_regions);
    
    [labels, features,all_ovps,is_gt_region,orig_inds] = collectFeatures(featStruct,stage_params(2).features);
    f = apply_region_classifier(stage_2_classifier,features,stage_params(2));
    disp('stage 2');
    displayRegions(I,selected_regions,f(:),0,1);
end


%% try some stuff on the phrasal recognition dataset...
baseDir = '/home/amirro/storage/data/UIUC_PhrasalRecognitionDataset/VOC3000/JPEGImages';
cacheTag = '~/storage/phrasal_rec';
funs = struct('tag',{},'fun',{});
funs(1).tag = 'faces';
funs(1).fun = 'fra_faces_baw_new';
funs(2).tag = 'face_landmarks';
funs(2).fun = 'my_facial_landmarks_new';
funs(3).tag = 'seg';
funs(3).fun = 'fra_face_seg_new';
funs(4).tag = 'obj_pred';
funs(4).fun = 'fra_obj_pred_new';
funs(5).tag = 'feat_pipeline_r';
funs(5).fun = 'fra_feature_pipeline_new';
funs(6).tag = 'ELSD';
funs(6).fun = 'run_elsd';

% run a
for t = 1:length(funs)
    funs(t).outDir = fullfile(cacheTag,funs(t).tag);
end
pipelineStruct = struct('baseDir',baseDir,'funs',funs);

%%
[paths,names] = getAllFiles(baseDir,'.jpg');
%%
all_class_scores = -inf(length(names),5);
%%
LL = cell(size(paths));
%%
for iImg =1:length(paths)
    iImg
    if (isempty(LL{iImg}))
        % load the basic features
        resPath = j2m(funs(5).outDir,names{iImg});
        if (~exist(resPath))
            continue
        end
        %     break
        L = load(resPath);
        LL{iImg} = L;
    end
end
%%
for iImg = 1:length(paths)
    iImg
    L = LL{iImg};
    if (isempty(L)),continue,end
    
    for iStage = 1%:length(stage_params)
        curParams = stage_params(iStage);
        featData = L.res.featData;
        [~,currentFeatures] = collectFeatures({featData},curParams.features);
        for iClass = 1
            if (strcmp(classifierType ,'rand_forest'))
                [hs,probs] = forestApply( currentFeatures', stage_forests{1});
                decision_values = probs(:,2);
            else
                decision_values = adaBoostApply(currentFeatures',obj(1).model,[],[],8);
            end
            %             f = adaBoostApply(currentFeatures',obj(iClass).model,[],[],8);
            all_class_scores(iImg,iClass) = max(decision_values(:));
            %         all_all_class_scores{u,1} = decision_values;
        end
    end
end

%%

[r,ir] = sort(all_class_scores(:,1),'descend');
% curSet = test_set;
for ff =1:length(paths)
    ff
    f = ir(ff);
    % load the basic features
    resPath = j2m(funs(5).outDir(1:end-2),names{f});
    if (~exist(resPath,'file'))
        warning ('file doesn''t exist - skipping');
        continue
    end
    faceScore = LL{f}.res.curImageData.faceScore
    if (faceScore < 1),continue,end
    L = load(resPath);
    featData = L.res.featData;
    curImgData = L.res.curImageData;
    
    for iStage = 1%:length(stage_params)
        curParams = stage_params(iStage);
        [~,currentFeatures] = collectFeatures({featData},curParams.features);
        if (strcmp(classifierType ,'rand_forest'))
            [hs,probs] = forestApply( currentFeatures', stage_forests{1});
            decision_values = probs(:,2);
        else
            decision_values = adaBoostApply(currentFeatures',obj(1).model,[],[],8);
        end
        %             f = adaBoostApply(currentFeatures',ob
        %                 [r,probs] = forestApply( single(currentFeatures)', stage_forests{iStage});
        
        [rois,roiBox,I,scaleFactor,roiParams] = get_rois_fra(conf,curImgData,params.roiParams);
        curMasks = {featData.feats.mask};
        %         curParams.debug = true;
        %         curParams1 = defaultPipelineParams(false);
        %         curParams1.debug = true;
        %         curParams1.pipelineParams = pipelineStruct.funs;
        extract_all_features_new(conf,curImgData,curParams1,featData);
        
        figure(2);%
        clf
        displayRegions(I,curMasks,decision_values,0,5);
        %         featData.segmentation.candidates.masks = curMasks(ik(1:100));
        continue;
        %%
        [zz,izz] = sort(probs,'descend');
        featData.segmentation.candidates.masks = curMasks(izz(1:10));
        featData = extract_all_features(conf,fra_db(u), stage_params(iStage+1),featData);
        [k,ik] = sort(decision_values,'descend');
        %%
        %         for tt = 1:10
        %             V = imfilter(im2double(curMasks{ik(tt)}),fspecial('gauss',[41 41],19));
        %             V = normalise(V);
        %             seg = st_segment(I,V,.5,3);
        %             displayRegions(I,seg);
        %             %gc_segResult = getSegments_graphCut_2(I,curMasks{ik(tt)},[],1);
        %             pause;
        %         end
        %         [regions,ovp,sel_] = chooseRegion(I,curMasks,.5);
        %         displayRegions(I,regions,ovp)
        
        %%
    end
    %     break;
end


%% just as a quirk, run the dnn fc6 features on all s40 dataset....
global_res = struct('class_name',{},'classifier',{},'test_labels',{},'test_scores',{},'results',{});
global_classifiers = {};
class_ids = [s40_fra.classID];
is_train = [s40_fra.isTrain];
for iClass = 1:length(conf.classes)
    global_res(iClass).class_name = conf.classes(iClass);
    global_res(iClass).classifier_global = train_classifier_helper(s40_fra,global_feats,iClass);
    global_res(iClass).test_scores = global_res(iClass).classifier_global.w(1:end-1)'*global_feats(:,~is_train);
    global_res(iClass).test_labels = 2*(class_ids(~is_train)==iClass)-1;
    [results.recall,results.precision,results.info] = vl_pr(global_res(iClass).test_labels,global_res(iClass).test_scores);        
    global_res(iClass).results = results;
end

results = [global_res.results];
infos = [results.info];
aps = [infos.ap];
%%
% hstem(1:40,aps);
clf; h = figure(1); hold on;
plot(aps,1:40,'go','LineWidth',3)
% ylim([0 41]);
set(gca,'YTickLabels',conf.classes)
set(gca,'YTick',1:40)
    grid on

for t = 1:length(aps)
%    plot([0 aps(t)], [t t],'k-');
end
       
for iClass = 1:length(classes)    
    plot(perf_no_global(iClass).info.ap,classes(iClass),'bo','LineWidth',3);    
    plot(perf_and_crop_and_global(iClass).info.ap,classes(iClass),'ro','LineWidth',3);
%     plot([0 perf_and_crop_and_global(iClass).info.ap], [classes(iClass) classes(iClass)],'k-');
end

xlabel('Avg. precision');
%ylabel('class');
addpath('~/code/3rdparty/export_fig');
legend({'Global','Ours','Ours+Global'})

%%
export_fig stanford_40_res.eps 

mean(aps)

aps2 = aps;
aps2(classes) = ap_infos_with_all;

mean(aps2)
