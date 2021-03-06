initpath;
config;

conf.class_subset = conf.class_enum.DRINKING;

[train_ids,train_labels,all_train_labels] = getImageSet(conf,'train',1,0);
[test_ids,test_labels,all_test_labels] = getImageSet(conf,'test');

conf.max_image_size = inf;
% prepare the data...

%%

load train_landmarks_full_face.mat;
load test_landmarks_full_face.mat;
load newFaceData.mat;
load newFaceData2.mat

% remove the images where no faces were detected.
train_labels = train_labels(train_dets.cluster_locs(:,11));
test_labels=test_labels(test_dets.cluster_locs(:,11));
% and do the same for the ids.
%
[faceLandmarks_train,lipBoxes_train,faceBoxes_train] = landmarks2struct(train_landmarks_full_face);
train_face_scores = [faceLandmarks_train.s];
[r_train,ir_train] = sort(train_face_scores,'descend');
[faceLandmarks_test,lipBoxes_test,faceBoxes_test] = landmarks2struct(test_landmarks_full_face);
test_face_scores = [faceLandmarks_test.s];
[r_test,ir_test] = sort(test_face_scores ,'descend');

train_labels_sorted = train_labels(ir_train);
test_labels_sorted = test_labels(ir_test);
m_train = multiImage(train_faces(ir_train(train_labels_sorted)),true);
figure,imshow(m_train);
m_test = multiImage(test_faces(ir_test(test_labels_sorted)),true);
figure,imshow(m_test);
%%
min_train_score  =-.882;
min_test_score = min_train_score;
t_train = train_labels(train_face_scores>=min_train_score);
t_test = test_labels(test_face_scores>=min_test_score);



%%
close all;
train_faces = train_faces(train_face_scores>=min_train_score);
get_full_image = get_full_image(train_face_scores>=min_train_score);

test_faces = test_faces(test_face_scores>=min_test_score);
test_faces_2 = test_faces_2(test_face_scores>=min_test_score);

lipBoxes_train_r = lipBoxes_train(train_face_scores>=min_train_score,:);
lipBoxes_test_r = lipBoxes_test(test_face_scores>=min_test_score,:);

train_faces_scores_r = train_face_scores(train_face_scores>=min_train_score);
test_faces_scores_r = test_face_scores(test_face_scores>=min_test_score);

lipBoxes_train_r_2 = round(inflatebbox(lipBoxes_train_r,[64 64],'both','abs'));

lipImages_train = multiCrop(conf,train_faces,lipBoxes_train_r_2,[64 NaN]);

figure,imshow(multiImage(lipImages_train(t_train),false));

lipBoxes_test_r_2 = round(inflatebbox(lipBoxes_test_r,[64 64],'both','abs'));
lipImages_test = multiCrop(conf,test_faces,lipBoxes_test_r_2,[64 NaN]);

figure,imshow(multiImage(lipImages_test(t_test),false));

%%
conf.suffix = 'rgb';
dict = learnBowDictionary(conf,train_faces(t_train),true);
model.numSpatialX = [2];
model.numSpatialY = [2];
model.kdtree = vl_kdtreebuild(dict) ;
model.quantizer = 'kdtree';
model.vocab = dict;
model.w = [] ;
model.b = [] ;
model.phowOpts = {'Color','RGB'};


if (exist('bowScanFeats.mat','file'))
    load bowScanFeats.mat;
else
    train_hists = {};
    test_hists = {};
        conf.features.vlfeat.cellsize = 8;
    parfor k = 1:length(train_faces)
        k
        %train_hists{k}= bowScan( conf,model, train_faces{k});
        train_hists{k}= hogScan( conf,model, train_faces{k});
    end
    
    parfor k = 1:length(test_faces)
        k
        %test_hists{k}= bowScan( conf,model, test_faces{k});
        test_hists{k}= hogScan( conf,model, test_faces{k});
    end
    
    save bowScanFeats.mat train_hists test_hists
end

f_proto = train_hists(2:2:end);
f_check = train_hists(1:2:end);

milFeatsTrain = milFeatures2(f_check,f_proto);
milFeatsTest = milFeatures2(test_hists,f_proto);

save milFeatsAll milFeatsTrain milFeatsTest;

y_train = 2*(t_train==1)-1;
y_test = 2*(t_test==1)-1;
sig_ = 5;
milFeatsTrain_2 = exp(-milFeatsTrain/sig_);

y_train_check = y_train(1:2:end);

r = repmat((1:9)',1,length(y_train));
r_proto = r(:,2:2:end);
train_faces_proto = train_faces(2:2:end);
train_faces_check = train_faces(1:2:end);
y_train_proto = t_train(2:2:end);
figure,imshow(multiImage(train_faces_check(y_train_check==1)));

ss = '-t 0 -c .01 w1 1';

[ws,b,sv,coeff] = train_classifier(milFeatsTrain_2(:,y_train_check==1),...
    milFeatsTrain_2(:,y_train_check==-1),.001,1);
% svmModel_mil= svmtrain(y_train_check, double(milFeatsTrain_2'),ss);
[r,ir] = sort((ws),'descend');
[ii,jj] = ind2sub(size(r_proto),ir);

figure,imshow(multiImage(train_faces_proto(jj(1:30))))

for k = 1:100%length(train_faces)
    bowScan( conf,model, train_faces_proto{jj(k)},ii(k));
end


[r,ir] = sort(milFeatsTrain,2,'ascend');
f = find(y_train_proto==1);
figure,imshow(train_faces_proto{f(2)});

aa = ir(((f(2)-1)*9):((f(2)-1)*9+9),:);
for q = 1:length(train_faces_proto)
    g = ((q-1)*9+1):q*9;
    aa = ir(g,:);
    for k = 1:size(aa,1)    
        imshow(multiImage([train_faces_proto{q},train_faces_check(aa(k,1:10))]));
        pause;
    end
end


[~, ~, dt_train_1] = svmpredict(zeros(size(y_train_check,1),1),double('),svmModel_mil);

dt_train_1 = ws'*milFeatsTrain_2;

train_faces_check = train_faces(1:2:end);
[r,ir] = sort(dt_train_1,'descend');
figure,imshow(multiImage(train_faces_check(ir(1:20))));

milFeatsTest_2 = exp(-milFeatsTest/sig_);
dt_test_1 = ws'*milFeatsTrain_2;

% [~, ~, dt_test_1] = svmpredict(zeros(size(y_test,1),1),double(milFeatsTest_2'),svmModel_mil);

[r,ir] = sort(dt_test_1,'descend');
figure,imshow(multiImage(test_faces(ir(1:100))));

%%


conf.suffix = 'rgb';
dict = learnBowDictionary(conf,train_faces(t_train),true);
model.numSpatialX = [2];
model.numSpatialY = [2];
model.kdtree = vl_kdtreebuild(dict) ;
model.quantizer = 'kdtree';
model.vocab = dict;
model.w = [] ;
model.b = [] ;
model.phowOpts = {'Color','RGB'};
% figure,imshow(getImage(conf,train_ids{train_dets.cluster_locs(550,11)}));

train_ids_d = train_ids(train_dets.cluster_locs(:,11));
train_ids_d = train_ids_d(train_face_scores>=min_train_score);
test_ids_d = test_ids(test_dets.cluster_locs(:,11));
test_ids_d = test_ids_d(test_face_scores>=min_test_score);

psix_train_local = getBOWFeatures(conf,model,lipImages_train);
psix_test_local = getBOWFeatures(conf,model,lipImages_test);
psix_train_face = getBOWFeatures(conf,model,train_faces);
psix_test_face = getBOWFeatures(conf,model,test_faces);

conf.features.vlfeat.cellsize = 8;
flat = true;
hog_train_face = imageSetFeatures2(conf,train_faces,flat,[40 40]);
hog_test_face = imageSetFeatures2(conf,test_faces,flat,[40 40]);
hog_train_face_2 = imageSetFeatures2(conf,get_full_image,flat,1.5*[40 40]);
hog_test_face_2 = imageSetFeatures2(conf,test_faces_2,flat,1.5*[40 40]);
[hog_train_local,sz] = imageSetFeatures2(conf,lipImages_train,flat,[48 48]);
hog_test_local = imageSetFeatures2(conf,lipImages_test,flat,[48 48]);
hog_train_global_d = imageSetFeatures2(conf,train_ids_d,1,[64 48]);
hog_test_global_d = imageSetFeatures2(conf,test_ids_d,1,[64 48]);

%
%% add some saliency-driven features.
% mkdir('tmp_train');
% mkdir('tmp_test');
% multiWrite(train_faces,'tmp_train2');
% multiWrite(test_faces,'tmp_test2');
% %
[train_sal] = multiRead('tmp_train_res','.png');
[test_sal] = multiRead('tmp_test_res','.png');

conf.features.vlfeat.cellsize = 8;
flat = true;
hog_train_face_sal = imageSetFeatures2(conf,train_sal,flat,[40 40]);
hog_test_face_sal = imageSetFeatures2(conf,test_sal,flat,[40 40]);

psix_train_face_sal = getBOWFeatures(conf,model,train_faces,train_sal);
psix_test_face_sal = getBOWFeatures(conf,model,test_faces,test_sal);

train_sal_small = multiCrop(conf,train_sal,[],[16 16]);
test_sal_small = multiCrop(conf,test_sal,[],[16 16]);

lipSal_train = multiCrop(conf,train_sal,lipBoxes_train_r_2,[1 1]);
lipSal_test = multiCrop(conf,test_sal,lipBoxes_test_r_2,[1 1]);
% train_sal_small = {};
% test_sal_small = {};
for k = 1:length(train_sal_small)
    train_sal_small{k} = train_sal_small{k}(:);
    lipSal_train{k} = lipSal_train{k}(:);
    
end
train_sal_small = im2double(cat(2,train_sal_small{:}));
lipSal_train = im2double(cat(2,lipSal_train{:}));

for k = 1:length(test_sal_small)
    test_sal_small{k} = test_sal_small{k}(:);
    lipSal_test{k} = lipSal_test{k}(:);
    
end
test_sal_small = im2double(cat(2,test_sal_small{:}));
lipSal_test = im2double(cat(2,lipSal_test{:}));

%
% [train_sal_global] = multiRead('~/data/jpeg_images_crop_res/','.png',train_ids_d);
% [test_sal_global] = multiRead('~/data/jpeg_images_crop_res/','.png',test_ids_d);
% %

% psix_train_sal_global = getBOWFeatures(conf,model,train_ids_d,train_sal_global);
% psix_test_sal_global = getBOWFeatures(conf,model,test_ids_d,test_sal_global);

% figure,imshow(multiImage(train_sal_small(t_train),false))

save allFeats.mat   psix_train_local psix_test_local...
    psix_train_face psix_test_face...
    hog_train_face hog_test_face...
    hog_train_local hog_test_local...
    hog_train_global_d hog_test_global_d...
    hog_train_face_2 hog_test_face_2...
    hog_train_face_sal hog_test_face_sal...
    psix_train_face_sal psix_test_face_sal;


% figure,imshow(multiImage(train_sal(t_train)))
% figure,imshow(multiImage(train_faces(t_train)))
%% and another channel which is bow x saliency.


%%
% choose a category
conf.class_subset = conf.class_enum.DRINKING;
[train_ids,train_labels,all_train_labels] = getImageSet(conf,'train',1,0);
[test_ids,test_labels,all_test_labels] = getImageSet(conf,'test');
train_labels=train_labels(train_dets.cluster_locs(:,11));
test_labels=test_labels(test_dets.cluster_locs(:,11));

t_train = train_labels(train_face_scores>=min_train_score);
t_test = test_labels(test_face_scores>=min_test_score);

imshow(multiImage(test_faces(t_test)));

y_train = 2*(t_train==1)-1;
y_test = 2*(t_test==1)-1;

ss = '-t 0 -c .001 w1 1';
svmModel_bow_face= svmtrain(y_train, double(psix_train_face'),ss);
svmModel_bow_face_sal= svmtrain(y_train, double(psix_train_face_sal'),ss);

svmModel_bow_local= svmtrain(y_train, double(psix_train_local'),ss);
svmModel_hog_face= svmtrain(y_train, double(hog_train_face'),ss);
svmModel_hog_face_sal= svmtrain(y_train, double(hog_train_face_sal'),ss);

svmModel_hog_face_2= svmtrain(y_train, double(hog_train_face_2'),ss);
svmModel_hog_local= svmtrain(y_train, double(hog_train_local'),ss);
svmModel_hog_global= svmtrain(y_train, double(hog_train_global_d'),ss);

svmModel_sal_patch= svmtrain(y_train, double(train_sal_small'),ss);
svmModel_lipSal_patch= svmtrain(y_train, double(lipSal_train'),ss);

svmModel_global_sal= svmtrain(y_train, double(psix_train_sal_global'),ss);


% add some more "specialized" detectors...
% figure,imshow(multiImage(train_faces(t_train)))

% bow scan does bow scanning window.
f = find(t_train);
f_test = find(t_test);
%%
% img = test_faces{f_test(7)};
% figure,subplot(2,1,1);imshow(img);
%  [ hists, q ] = bowScan( conf,model, img);
%
%  [~, ~, scan_1] = svmpredict(zeros(9,1),double(hists'),svmModel_bow_local);
% qq = zeros(size(q));
%  for z = 1:length(unique(q))
%      qq(q==z)=scan_1(z);
%  end
%
%  subplot(2,1,2),imagesc(qq);

allTrainScores = zeros(9,length(train_faces));
allTestScores = zeros(9,length(train_faces));
z = zeros(9,1);
parfor k = 1:length(train_faces)
    k
    [ hists] = bowScan( conf,model, train_faces{k});
    [~, ~, allTrainScores(:,k)] = svmpredict(z,double(hists'),svmModel_bow_local);
end

parfor k = 1:length(test_faces)
    k
    [ hists] = bowScan( conf,model, test_faces{k});
    [~, ~, allTestScores(:,k)] = svmpredict(z,double(hists'),svmModel_bow_local);
end


%%

x = hog_train_face(:,t_train);
[C,IC] = vl_kmeans(x,10, 'NumRepetitions', 100);
d_clusters = makeClusterImages(train_faces(t_train),C,IC,x,...
    'hogTrainFaceClusters');

% rects_drink_obj = selectSamples(conf,train_faces(t_train),'drinkObj');
% save rects_drink_obj rects_drink_obj;
load rects_drink_obj;

c = rects2clusters(conf,rects_drink_obj,train_faces(t_train),[],false);

cc = cat(2,c.cluster_samples);
cc = vl_kmeans(cc,20,'NumRepetitions',100);
% aa = cat(1,c.cluster_locs);
% a_c = visualizeLocs2_new(conf,train_faces(t_train),aa);
figure,imshow(multiImage(lipImages_train,false))% score the faces..
imshow(multiImage(train_faces(ir_train(1:20:end))));
sss = r_train(1:20:end);
ttt = false(size(sss));
ttt([1:56 58:63 66:67 69 72 74 76 80 96:98 113 127 131 147:148 157 164 172 177]) = true;

[w_,b_] = logReg(sss(:),ttt(:));

% curScores = sigmoid(sss*w+ b);
% plot(curScores);
% hold on;
% plot(ttt,'r+');
%

figure,plot(sigmoid(r_train*w_+b_))

min_train_score  =-.882;
min_test_score = min_train_score;
% min_test_score = -1;
t_train = train_labels(train_face_scores>=min_train_score);
t_test = test_labels(test_face_scores>=min_test_score);

% missingTestInds = (test_face_scores < min_train_score) & test_labels';
% test_ids_d_1 = test_ids(test_dets.cluster_locs(:,11));
% missingTestRects = selectSamples(conf,test_ids_d_1(missingTestInds),'missingTestTrueFaces');
% missingTestRects = cat(1,missingTestRects{:});
% missingTestRects(:,4) = missingTestRects(:,4)+missingTestRects(:,2);
% missingTestRects(:,3) = missingTestRects(:,3)+missingTestRects(:,1);
% save missingTestRects.mat missingTestRects missingTestInds


figure,imshow(multiImage(lipImages_test(t_test),false));

theClusts = makeClusters(cc,[]);
conf.features.winsize = [8 8];
%clusters_t = train_patch_classifier(conf,c,train_faces(~t_train),'suffix','drinkers2','override',true);
clusters_t = train_patch_classifier(conf,theClusts,train_faces(~t_train),'suffix','drinkers2','override',false);
conf.detection.params.detect_add_flip = 1;
conf.detection.params.detect_min_scale = .8;
[q_tt] = applyToSet(conf,clusters_t,train_faces,[],'drinkers_train2','override',false);
[q_t] = applyToSet(conf,clusters_t,test_faces,[],'drinkers_test2','override',false);

tt_faces = train_faces(t_train);
tt_faces_f = train_faces(~t_train);

discovery_sets = { tt_faces(1:2:end),tt_faces(2:2:end)};
natural_sets = { tt_faces_f(1:2:end),tt_faces_f(2:2:end)};
clusters=refineClusters(conf,clusters_t,discovery_sets,natural_sets,'drinkers_refine');

[q_tt2] = applyToSet(conf,clusters,train_faces,[],'drinkers_train2_ref','override',false);
[q_t2] = applyToSet(conf,clusters,test_faces,[],'drinkers_test2_ref','override',false);

[~,~,qq_train] = combineDetections(q_tt);
[~,~,qq_test] = combineDetections(q_t);

ws = [];
for q = 1:size(C,2)
    q
    [w] = train_classifier(d_clusters(q).cluster_samples ,hog_train_face(:,~t_train),.01,10);
    ws = [ws,w];
end
%
[~, ~, dt_train_1] = svmpredict(zeros(size(t_train,1),1),double(psix_train_face'),svmModel_bow_face);
[~, ~, dt_train_2] = svmpredict(zeros(size(t_train,1),1),double(psix_train_local'),svmModel_bow_local);
[~, ~, dt_train_3] = svmpredict(zeros(size(t_train,1),1),double(hog_train_face'),svmModel_hog_face);
[~, ~, dt_train_4] = svmpredict(zeros(size(t_train,1),1),double(hog_train_local'),svmModel_hog_local);
[~, ~, dt_train_5] = svmpredict(zeros(size(t_train,1),1),double(hog_train_global_d'),svmModel_hog_global);
[~, ~, dt_train_6] = svmpredict(zeros(size(t_train,1),1),double(hog_train_face_2'),svmModel_hog_face_2);
[~, ~, dt_train_7] = svmpredict(zeros(size(t_train,1),1),double(hog_train_face_sal'),svmModel_hog_face_sal);
[~, ~, dt_train_8] = svmpredict(zeros(size(t_train,1),1),double(psix_train_face_sal'),svmModel_bow_face_sal);
[~, ~, dt_train_9] = svmpredict(zeros(size(t_train,1),1),double(train_sal_small'),svmModel_sal_patch);
dt_train_10 = double(lipSal_train');
dt_train_11 = sigmoid(train_face_scores(train_face_scores>=min_train_score)*w_+b_);
% dt_train_12 = min(allTrainScores)';
% [~, ~, dt_train_13] = svmpredict(zeros(size(t_train,1),1),double(psix_train_sal_global'),svmModel_global_sal);


dt_train_999 = (ws'*hog_train_face)';

[~, ~, dt_test_1] = svmpredict(zeros(size(t_test,1),1),double(psix_test_face'),svmModel_bow_face);
[~, ~, dt_test_2] = svmpredict(zeros(size(t_test,1),1),double(psix_test_local'),svmModel_bow_local);
[~, ~, dt_test_3] = svmpredict(zeros(size(t_test,1),1),double(hog_test_face'),svmModel_hog_face);
hog_test_face_flipped = imageSetFeatures2(conf,test_faces,flat,-[40 40]);
[~, ~, dt_test_3_flipped] = svmpredict(zeros(size(t_test,1),1),double(hog_test_face_flipped'),svmModel_hog_face);
[~, ~, dt_test_4] = svmpredict(zeros(size(t_test,1),1),double(hog_test_local'),svmModel_hog_local);
[~, ~, dt_test_5] = svmpredict(zeros(size(t_test,1),1),double(hog_test_global_d'),svmModel_hog_global);
[~, ~, dt_test_6] = svmpredict(zeros(size(t_test,1),1),double(hog_test_face_2'),svmModel_hog_face_2);
[~, ~, dt_test_7] = svmpredict(zeros(size(t_test,1),1),double(hog_test_face_sal'),svmModel_hog_face_sal);
[~, ~, dt_test_8] = svmpredict(zeros(size(t_test,1),1),double(psix_test_face_sal'),svmModel_bow_face_sal);
[~, ~, dt_test_9] = svmpredict(zeros(size(t_test,1),1),double(test_sal_small'),svmModel_sal_patch);
dt_test_10 = double(lipSal_test');
dt_test_11 = sigmoid(test_face_scores(test_face_scores>=min_test_score)*w_+b_);
% dt_test_12 = min(allTestScores)';
[~, ~, dt_test_13] = svmpredict(zeros(size(t_test,1),1),double(psix_test_sal_global'),svmModel_global_sal);
dt_test_999 = (ws'*hog_test_face)';

% HERE-------------------
%%
ddd = 1;

feat_train_all = [dt_train_1(:),dt_train_2(:),dt_train_3(:),dt_train_4(:),dt_train_5(:),dt_train_6(:),dt_train_7,dt_train_8,dt_train_9,dt_train_10,dt_train_11(:),train_faces_scores_r(:)];
feat_train_all = double(feat_train_all);
sel = [1 4 5 7 8 9 10] ;
% sel = [1];  % bow face - 18%
% sel = [3]; % hog face - 18&
% sel = [5];


[ws,bs] = getLogRegCoefficients2(feat_train_all,t_train);

% for k = 1:length(ws)
%     feat_train_all(:,k) = sigmoid(feat_train_all(:,k)*ws(k) + bs(k));
% end
sel_add = [1:10];
feat_train_all = [feat_train_all(:,sel),double(dt_train_999(:,sel_add)),qq_train];

% [r,ir] = sort(dt_train_5,'ascend');
% figure,imshow(multiImage(train_faces(ir(1:50)),false))
% [r,ir] = sort(dt_test_5,'ascend');
% figure,imshow(multiImage(test_faces(ir(1:50)),false))

means  = mean(feat_train_all);
vars = std(feat_train_all);

feat_train_all = bsxfun(@minus,feat_train_all,means);
feat_train_all = bsxfun(@rdivide,feat_train_all,vars);


svmModel_all= svmtrain(y_train,feat_train_all,'-t 0 -c .0000001 w1 1');
% dt_test_3_with_flip = max(dt_test_3,dt_test_3_flipped);
dt_test_3_with_flip = dt_test_3;
feat_test_all = [dt_test_1(:),ddd*dt_test_2(:),dt_test_3_with_flip(:),dt_test_4(:),dt_test_5(:),dt_test_6(:),dt_test_7(:),dt_test_8(:),dt_test_9(:),dt_test_10(:),dt_test_11(:),test_faces_scores_r(:)];
feat_test_all = [feat_test_all(:,sel),double(dt_test_999(:,sel_add)),qq_test];
feat_test_all = double(feat_test_all);

% for k = 1:length(ws)
%     feat_test_all(:,k) = sigmoid(feat_test_all(:,k)*ws(k) + bs(k));
% end
% % %
feat_test_all = bsxfun(@minus,feat_test_all,means);
feat_test_all = bsxfun(@rdivide,feat_test_all,vars);
%
% svmModel_all= svmtrain(y_test, feat_test_all,'-t 0 -c 100 w1 1');

[~, ~, decision_values_test] = svmpredict(zeros(size(t_test,1),1),double(feat_test_all),svmModel_all);

%decision_values_test(f) =0;
% decision_values_test(f) = rand(size(f))*(max(decision_values_test)-min(decision_values_test))+min(decision_values_test);
scores_ = -decision_values_test;%(D_M_test_*ws);
[r,ir] = sort(scores_,'descend');
% plot(cumsum(rr(ir)))

% plot(cumsum(t_test(ir)))

% test_faces_p = paintRule(test_faces,t_test,[],[],3);
% figure,imshow(multiImage(test_faces(ir(1:100)),false))
% imwrite(multiImage(test_faces_p(ir(1:300))),'drink_results.tif');

% mm = multiImage(test_faces(ir(1:150)));
% imwrite(mm,'docs/brushing_results_using_mouth.tif');
%  figure,imshow(multiImage(lipImages_test(ir(1:140)),false))

%
[prec,rec,aps] = calc_aps2(scores_,t_test,sum(test_labels))
% [prec,rec,aps] = calc_aps2(scores_(~t_test_dontcare),t_test(~t_test_dontcare),sum(test_labels(~test_dontcare)));
figure,plot(rec,prec); title(num2str(aps));


%%

%%

f = train_faces(t_train);
f_ = train_sal(t_train);

%%
for k = 1:length(f)
    
    %     labels = getMultipleSegmentations(f{1});
    sigma_=.8;
    minSize = 15;
    im = f{k};
    curIm = uint8(rgb2lab(im));
    sal_map = im2double(f_{k});
    labels = mexFelzenSegmentIndex(im, sigma_, minSize, 20);
    
    %figure,imagesc(labels)
    rr = regionprops(labels,sal_map,'PixelIdxList','Area','MeanIntensity');
    Z = paintRegionProps(labels,rr,[rr.MeanIntensity].*([rr.Area].^.5));
    clf;
    subplot(2,2,1);
    imagesc(im);
    subplot(2,2,2);
    imagesc(sal_map);
    subplot(2,2,3);
    imagesc(labels);
    subplot(2,2,4);
    imagesc(Z);
    pause;
end
%%
% figure,imagesc(Z)


%ttt = train_ids_d_t(t_train);
% ttt = lipImages_train(t_train);
%%
ttt = get_full_image(t_train);
for k = 1:length(ttt)
    im = im2uint8(getImage(conf,ttt{k}));
    %     im = imfilter(im,fspecial('gauss',9,2));
    %     myGetSkinRegions(im);
    %bb = [1 1 size(im,2) size(im,1)];
    %     bb = faceBoxes_train_1(:,k);
    %      myGetSkinRegions(im,round(bb));
    skinprob = computeSkinProbability(double(im));
    r0  = im;
    r1 = im2uint8(jettify(skinprob));
    imshow([r0,r1]);
    pause;
end

%
% imshow(train_faces{1})
% im = train_faces{1};
% myGetSkinRegions(im);

%% figure,imshow(multiImage(test_faces(ir(1:50))))
scores_ = -decision_values_test;%(D_M_test_*ws);
[r,ir] = sort(scores_,'descend');
% figure,imshow(multiImage(test_faces(ir(1:100))))
[prec,rec,aps] = calc_aps2(scores_,t_test,sum(test_labels))
figure,plot(rec,prec); title(num2str(aps));
%% figure,imshow(multiImage(test_faces(ir(1:100))))
figure,imshow(multiImage(test_faces(ir(1:50))))
% figure,imshow(multiImage(lipImages_test(ir(1:150)))

%%
ddd = 1;

feat_train_all = [dt_train_1(:),dt_train_2(:),dt_train_3(:),dt_train_4(:),dt_train_5(:)];

t = classregtree(feat_train_all,t_train(2:2:end));

% [r,ir] = sort(dt_train_5,'ascend');
% figure,imshow(multiImage(train_faces(ir(1:50)),false))
% [r,ir] = sort(dt_test_5,'ascend');
% figure,imshow(multiImage(test_faces(ir(1:50)),false))

means  = mean(feat_train_all);
vars = std(feat_train_all);

feat_train_all = bsxfun(@minus,feat_train_all,means);
feat_train_all = bsxfun(@rdivide,feat_train_all,vars);


svmModel_all= svmtrain(y_train(2:2:end),feat_train_all,'-t 0 -c .1 w1 1');

feat_test_all = [[dt_test_1(:),ddd*dt_test_2(:),dt_test_3(:),dt_test_4(:)],dt_test_5(:)];

feat_test_all = bsxfun(@minus,feat_test_all,means);
feat_test_all = bsxfun(@rdivide,feat_test_all,vars);

% svmModel_all= svmtrain(y_test, feat_test_all,'-t 0 -c 100 w1 1');

[predicted_label, ~, decision_values_test] = svmpredict(zeros(size(t_test,1),1),double(feat_test_all),svmModel_all);

%decision_values_test = decision_values_test;
decision_values_test = dt_test_1(:);



% svmModel_all= svmtrain(y_test, feat_train_all,'-t 0 w1 1');
% decision_values_test = feat_test_all*[1 1 .001*([10 1])]';
% figure,imshow(multiImage(test_faces(ir(1:50))))
scores_ = -decision_values_test;%(D_M_test_*ws);

% [yfit,nodes,cnums] = eval(t,feat_test_all);
% scores_ = cnums;
[r,ir] = sort(scores_,'descend');
% figure,imshow(multiImage(test_faces(ir(1:100))))
[prec,rec,aps] = calc_aps2(scores_,t_test,sum(test_labels))
figure,plot(rec,prec); title(num2str(aps));
%% figure,imshow(multiImage(test_faces(ir(1:50))))
scores_ = -decision_values_test;%(D_M_test_*ws);
[r,ir] = sort(scores_,'descend');
% figure,imshow(multiImage(test_faces(ir(1:100))))
[prec,rec,aps] = calc_aps2(scores_,t_test,sum(test_labels))
figure,plot(rec,prec); title(num2str(aps));
%% figure,imshow(multiImage(test_faces(ir(1:100))))
figure,imshow(multiImage(test_faces(ir(1:50))))
figure,imshow(multiImage(lipImages_test(ir(1:150))))
%%
% m = train_faces(t_train);
m = test_faces(ir);
%%
% m = lipImages_train(~t_train);
% imshow(m{1})
for k = 1:length(m)
    
    % for k = 11
    im = m{k};
    im = im2double(im);
    im = imfilter(im,fspecial('gauss',5, 2));
    %     figure,imshow(im);
    im_1 = vl_xyz2luv(vl_rgb2xyz(im));
    im_1 = (rgb2hsv(im));
    % im_1 = im;
    % lipColors = reshape(im2double(mm{k}),[],size(mm{k},3));
    % imshow(im2double(mm{k}))
    imcolors = reshape(im_1,[],size(im,3));
    obj = gmdistribution.fit(imcolors,1);
    
    h = pdf(obj,imcolors);
    Z0 = reshape(h,size(im,1),size(im,2));
    
    r0 = im;
    %r1 = im2double(jettify(Z0));
    Z0 = Z0/max(Z0(:));
    r1 = repmat(Z0,[1 1 3]);
    r2 = edge(Z0,'canny');
    
    r2 = repmat(r2,[1 1 3]);
    r3 = edge(rgb2gray(im),'canny');
    r3 = repmat(r3,[1 1 3]);
    bsize = [3 3];
    B = [];
    for c= 1:3
        B = [B;im2col(im_1(:,:,c),bsize,'distinct')];
    end
    
    b_d = l2(B',B');
    
    [r,ir] = sort(b_d,2,'ascend');
    r = r(:,2:end);
    %
    knn = 5;
    sigma_ = .1;
    z = sum(exp(-r(:,1:knn)/sigma_),2)/knn;
    z = repmat(z',prod(bsize),1);
    sz = size(im);
    
    b_z = col2im(z,bsize,sz(1:2),'distinct');
    b_z= b_z-min(b_z(:));
    b_z = b_z/max(b_z(:));
    b_z = b_z.^2;
    r4 = repmat(b_z,[1 1 3]);
    
    % figure,imagesc(b_z);
    r4 = jettify(b_z);
    imshow([r0 r1 r2 r3 r4]);
    
    
    pause;
end


% self similarity...

% imshow(im)
% p = im(65:69,37:41,:);
% imshow(p)


%%
mkdir('~/cropped');
parfor k = 1:length(train_ids)
    I = getImage(conf,train_ids{k});
    imwrite(I,fullfile('~/cropped',train_ids{k}));
end


parfor k = 1:length(test_ids)
    I = getImage(conf,test_ids{k});
    imwrite(I,fullfile('~/cropped',test_ids{k}));
end