% setup:

% function doStuff()
initStuff;
randn('state',0);
rand('state',0);

% ------------------------------------------------------------------
%                                                      Generate data
% ------------------------------------------------------------------
%debug_factors = [20 10 5];
debug_factors = [5];
model_types = {'nolearn','minimal','partial','full','full_edges'};
imgSizes = [64 80 100];
cellSize = 4;
windowSize = cellSize*5;
% imgSizes = [80];
% debug_factors = [25];
% imgSizes = [64];
debug_factors = [25];
% loc_fraction = .5;%.25;
loc_fraction = 1;
% imgSizes = [64 80  100];
imgSizes = 80;
% model_types = {'full'};
% model_types = {'full_edges'};
% model_types = {'minimal'};
model_types = {'nolearn'}
% model_types = {'partial'}
iExp = 0;
doBenchmark = true;
forceTrain = true;
param.keepDeadStates = true;
param.use_pairwise_scores = true;
param.use_location_prior = false;
isTreeStructure = true;

expResults = struct('name',{},'param',{},'model',{},'stats',{});
for iImgSize = 1:length(imgSizes)
    imgSize = imgSizes(iImgSize);
    for iDebugFactor = 1:length(debug_factors)
        debug_factor = debug_factors(iDebugFactor);
        for iModelType = 1:length(model_types)
            learningType = model_types{iModelType};
            kp_sel = [17 18 26]; % eyes and mouth
            %kp_sel = [9 11 12 10 23 22 24 29];
            kp_sel = [9 11 12 10 23 22 24 27 29];
            %kp_sel = [9 11 12 10];
            %             kp_sel = kp_sel(1:5)
%             kp_sel = 1:29;
            %                         kp_sel = [1:26 28 29];
%             kp_sel_bit = zeros(1,29);
            
            kp_sel_bit(kp_sel) = 1;
            kp_sel_str = strrep(num2str(kp_sel_bit),' ','');
            resPath = ['D:\datasets\cofw\models\model_sz' num2str(imgSize) '_d' num2str(debug_factor) '_t_' learningType '_kp_' kp_sel_str '.mat']
            if  forceTrain || ~exist(resPath,'file')
                % choose subset of keypoints.
                % make patterns and labels:
                % patterns are image level hogs
                % labels are the locations of the facial landmarks
                
                
                imgSize_c = imgSize/cellSize;
                windowSize_c = windowSize/cellSize;
                [ phis_tr_n ,factors] = normalize_coordinates( phisTr,IsTr,false);
                IsTr_1 = multiResize(IsTr,imgSize);
                IsTr_1 = cellfun2(@(x) condition(length(size(x))==3,x,cat(3,x,x,x)),IsTr_1);
                IsT_1 = multiResize(IsT,imgSize);
                IsT_1 = cellfun2(@(x) condition(length(size(x))==3,x,cat(3,x,x,x)),IsT_1);
                phis_tr_n = phis_tr_n(:,:,1:3);
                
                % size(phis_tr_n)
                
                patterns = IsTr_1;
                
                %             % left eye center, right eye center, center of mouth (approx.)
                % kp_sel = 17; % left eye center, right eye center, center of mouth (approx.)
                % kp_sel = [26]; % center of mouth...
                %             kp_sel = 1:29; % all keypoints
                %kp_sel = [1:27]; % kp 27 is problematic? what's the problem?
                %             kp_sel = [1:26 28 29]; % kp 27 is problematic, since it's too close to kp 26...
                
                %             kp_sel = [9:16];% 28 29]; % kp 27 is problematic, since it's too close to kp 26...
                %             kp_sel = [26 28:29]; % kp 27 is problematic, since it's too close to kp 26...
                %             kp_sel = 1:6:29;
                %                             kp_sel = 1:29;
                % % eye corners, mouth corners, tip of nose, chin
                
                nPts = length(kp_sel);
                labels = {};
                for t = 1:length(patterns)
                    labels{t} = reshape(phis_tr_n(t,kp_sel,:),[],3);
                end
                nPts = length(kp_sel);
                
                infer_visibility = false;
                
                % location prior: create a tree from the keypoint structure.
                
                % since all images are of the same size, can already model the prior & pairwise
                % constraints here.
                boxes = get_boxes_single_scale(windowSize, cellSize,zeros(imgSize,imgSize,3,'single'));
                all_locs = boxCenters(boxes)/imgSize;
                % generate the pairwise constraints for all pairs in the tree.
                nLocs = size(all_locs,1);
                param.nLocsAdmitted = round(loc_fraction*nLocs);
                all_kp_locs = cat(3,labels{:});
                toSnap = false;
                if (toSnap)
                    % snap to grid
                    for iLoc = 1:size(all_kp_locs,3)
                        curLocs = all_kp_locs(:,1:2,iLoc);
                        d = l2(curLocs,all_locs);
                        [m,im] = min(d,[],2);
                        all_kp_locs(:,1:2,iLoc) = all_locs(im,:);
                        labels{iLoc}(:,1:2) = all_locs(im,:);
                    end
                end
                % all_kp_visible = all_kp_locs(:,3,:);
                n_gaussian_components = 1;
                gaussian_models = {};
                % figure(1); clf;
                % hold on;
                loc_priors = zeros(nLocs,nPts);
                for t = 1:nPts
                    GMModel = fitgmdist(squeeze(all_kp_locs(t,1:2,:))',n_gaussian_components);%,'CovType','Diagonal');
                    gaussian_models{t} = GMModel;
                    loc_priors(:,t) = log_lh(GMModel,all_locs);
                    %ezcontour(@(x1,x2)pdf(GMModel,[x1 x2]),get(gca,{'XLim','YLim'}));
                    %     ezcontour(@(x1,x2)pdf(GMModel,[x1 x2]),4);
                    %     pause
                end
                %% model a pairwise term between patches, using distances.
                
                %                 for u = 1:size(loc_priors,2)
                %                     a = visualizeTerm(loc_priors(:,u),all_locs*imgSize,imgSize);
                %                     clf; imagesc(a); axis equal;drawnow ;pause;
                %                 end
                %
                
                Q = cat(4,IsTr_1{:});
                Q = mean(im2single(Q),4);
                
                % remove states that cannot happen : find the top-20 percent of
                % each prior.
                
                [z,iz] = sort(loc_priors,'descend');
                loc_admitted = false(size(loc_priors));
                for t = 1:nPts
                    loc_admitted(iz(1:param.nLocsAdmitted,t),t) = true;
                end
                
                yhats = zeros(nPts,param.nLocsAdmitted,2);
                for t = 1:nPts
                    yhats(t,:,:) = all_locs(loc_admitted(:,t),:);
                end
                %             for zz = 1:length(IsTr)
                %             clf;imagesc2(IsTr_1{zz});plotPolygons(imgSize*squeeze(yhats(1,:,:)),'r.')
                %             drawnow;pause;
                %             end
                param.yhats = yhats;
                % binarize it...
                param.loc_admitted = loc_admitted;
                %                 param.loc_prior = log(loc_priors);
                %             admitted_subsets = loc_priors > 1;
                
                gaussian_means = cellfun2(@(x) x.mu,gaussian_models);gaussian_means = cat(1,gaussian_means{:});
                G = l2(gaussian_means,gaussian_means).^.5;
                
                param.isTreeStructure = isTreeStructure;
                % make sure that only i > j entries are non zeros in adj.
                % matrix!!
                if isTreeStructure
                    adj = G;
                    [adj,pred] = graphminspantree(sparse(adj),'Method','Kruskal');
                    %                     adj = adj';
                else
                    %                 % make this a sparser model by removing long edges
                    G(G>.31) = 0;
                    for i = 1:nPts
                        for j = i:nPts
                            G(i,j) = 0;
                        end
                    end
                    
                    adj = sparse(G);
                end
                %                 adj = adj;
                %                 for img_sel = 1:40:400
                img_sel = 6;
                curImg = IsTr_1{img_sel};
                figure(10);clf ; imagesc2(curImg);
                sz = size(curImg,1);
                curCoords = sz*labels{img_sel}(:,1:2);
                %                 adj(3,1) = 0;adj(4,2) = 0;
                
                gplot2(adj,squeeze(sz*labels{img_sel}(:,1:2)),'g-','LineWidth',2);
                showCoords(curCoords);
                title('graph')
                %                 pause
                %                                 plotBoxes(inflatebbox(repmat(curCoords,1,2),windowSize,'both',true));
                %                                 pause;
                %                 end
                adj = double(adj > 0);
                [ii,jj] = find(adj);
                edges = [ii jj];
                nEdges = length(ii);
                
                %% define a pairwise score by a 2d-gaussian for the relative location
                % of each pair of keypoints.
                if loc_fraction == 1 || param.keepDeadStates
                    pairwise_scores = -inf(nLocs,nLocs,nEdges);
                else
                    pairwise_scores = -inf(param.nLocsAdmitted,param.nLocsAdmitted,nEdges);
                end
                %TODO: LOCADMIT
                %
                pair_gaussian_models = cell(nEdges,1);
                [loc_i,loc_j] = meshgrid(1:nLocs,1:nLocs);
                zz = all_locs(loc_j(:),:)-all_locs(loc_i(:),:);
                for iEdge = 1:nEdges
                    %                     iEdge
                    iPair = edges(iEdge,1);
                    jPair = edges(iEdge,2);
                    
                    offsets = squeeze(all_kp_locs(jPair,1:2,:)-all_kp_locs(iPair,1:2,:))';
                    pair_gaussian_models{iEdge} = fitgmdist(offsets,n_gaussian_components);%,'CovType','Diagonal');
                    %                     disp(edges(iEdge,:))
                    %                     pair_gaussian_models{iEdge}
                    % %     clf;
                    % %     ezcontour(@(u,v)pdf(pair_gaussian_models{iEdge},[u v]),300)
                    % %     hold on; plot(0,0,'r+');
                    % %     pause
                    p = log_lh(pair_gaussian_models{iEdge},zz);
                    %figure,imagesc2(IsTr_1{1})
                    p = reshape(p,nLocs,nLocs);
                    loc_subset_i =  loc_admitted(:,iPair);
                    loc_subset_j =  loc_admitted(:,jPair);
                    % TODO: LOCADMIT
                    if (loc_fraction==1 || param.keepDeadStates)
                        pairwise_scores(:,:,iEdge) = p;
                    else
                        pairwise_scores(:,:,iEdge) = p(loc_subset_i,loc_subset_j); %TODO?
                    end
                    
                    visualize_stuff = false;
                    if (visualize_stuff)
                        [xx,yy] = meshgrid((1:imgSize)/imgSize,(1:imgSize)/imgSize);
                        curMean = gaussian_models{iPair}.mu;
                        z = reshape(log_lh(pair_gaussian_models{iEdge},[xx(:)-curMean(1) yy(:)-curMean(2)]),size(xx));
                        prob_image = exp(z/2);
                        clf ; imagesc2(sc(cat(3,prob_image,curImg),'prob'));
                        sz = size(curImg,1);
                        curCoords = sz*labels{img_sel}(:,1:2);
                        plotPolygons(curMean*imgSize,'r+');
                        gplot2(adj,squeeze(sz*labels{img_sel}(:,1:2)),'g-','LineWidth',2);
                        showCoords(curCoords);
                        title(num2str(edges(iEdge,:)));
                        %                         continue
                        % do the same with the image locs: find the pairwise
                        % score relating to a specific location for i and read
                        % off the probabilities for the location of j
                        
                        % find the nearest neighbor to the eye corner
                        if (0)
                            clf ;imagesc2(curImg); [x1,y1] = ginput(1);
                            [u,iu] = min(l2([x1,y1]/imgSize,all_locs))
                            all_locs(iu,:)
                            log_probs = pairwise_scores(iu,:,iEdge);
                            m = visualizeTerm(log_probs',all_locs*imgSize,[imgSize imgSize]);
                            figure(1);imagesc2(exp(m));figure(2);imagesc2(curImg);
                        end
                        %                     figure,imagesc2(exp(z/2)); figure,imagesc2(IsTr_1{1})
                    end
                    %
                end
                
                %                 pairwise_scores(pairwise_scores==-inf) = min(pairwise_scores(pairwise_scores(:)>-inf));
                param.pairwise_scores = pairwise_scores;
                param.nEdges = nEdges;
                param.edges = edges;
                param.patterns = row(patterns(1:debug_factor:end));
                param.pair_gaussian_models = pair_gaussian_models;
                param.gaussian_models = gaussian_models;
                param.labels = row(labels(1:debug_factor:end));
                
                
                param.lossFn = @lossCB;
                param.lossType = 2;
                param.adj = adj;
                switch learningType
                    case {'minimal','nolearn'}
                        param.constraintFn  = @constraintCB_minimal;
                        param.featureFn = @featureCB_minimal;
                        wDim = 3;  % wvisible+winvisible+w_app
                    case {'minimal_occ','nolearn_occ'}
                        param.constraintFn  = @constraintCB_minimal_occ;
                        param.featureFn = @featureCB_minimal_occ;
                        wDim = 4;  % wvisible+winvisible+w_app
                    case 'partial'
                        param.constraintFn  = @constraintCB;
                        param.featureFn = @featureCB;
                        wDim = nPts+nEdges;
                    case 'full'
                        param.constraintFn  = @constraintCB_full;
                        param.featureFn = @featureCB_full;
                        wDim = (31*(windowSize/cellSize)^2)*nPts + nEdges;
                    case 'full_edges'
                        param.constraintFn  = @constraintCB_full_edges;
                        param.featureFn = @featureCB_full_edges;
                        wDim = (31*(windowSize/cellSize)^2)*nPts + nEdges*5;
                end
                
                param.dimension = wDim;
                % param.dimension = 2;
                
                param.verbose = 1;
                param.imgSize = imgSize;
                param.windowSize = windowSize;
                param.nPts = nPts;
                param.cellSize = cellSize;
                param.debug = false;
                
                if (~param.use_location_prior)
                    param.location_priors = zeros(size(loc_priors));
                else
                    param.location_priors = loc_priors;
                end
                param.use_appearance_feats = true;
                param.infer_visibility = infer_visibility;
                %                 param.rotations = -20:20:20;
                param.rotations = 0;
                
                % % %% first model : learn a random field for the locations.
                negImagePaths = getNonPersonImageList();
                %
                % save z z
                % train patch detectors
                
                detector_path = sprintf('detectors_img_%d_w_%d_c_%d.mat',imgSize,windowSize,cellSize);
                if (~exist(detector_path,'file'))
                    [~,param.patchDetectors] = learnPatchModels(param,negImagePaths);
                    z = param.patchDetectors;
                    save(detector_path,'z');
                else
                    load(detector_path);
                end
                param.patchDetectors = z(kp_sel,:);
                %             load z.mat;
                
                param.phase = 'train';
                %param.precompute_responses = true && strcmp(learningType,'partial');
                param.precompute_responses = false && strcmp(learningType,'partial');
                if (param.precompute_responses)
                    param.patterns = precompute_responses(param,param.patterns);
                end
                
                %% test a couple of samples to see if the patch detectors make sense
                % (relevant only for pre-trained detectors)
                % param.pwise_factor = 1;
                % param.unary_prior_factor = 0;
                
                if (0)
                    
                    param.debug = true;
                    
                    figure(1);
                    for g = 1:1:length(IsT)
                        curImg_orig = IsT{g};
                        %     curImg_orig = imread('C:\Users\amirro\Desktop\applauding_001_face1.jpg');
                        %     curImg_orig = imcrop(curImg_orig);
                        curImg = imResample(curImg_orig,[imgSize imgSize]);
                        
                        param.debug = false;
                        %     curImg = imrotate(curImg,30,'bilinear','crop');
                        [xy_pred,curScore,curRot] = apply_graphical_model(param,curImg);
                        curImg = imrotate(curImg,curRot,'bilinear','crop');
                        xy_pred = size(curImg,1)*xy_pred;
                        %     continue
                        xy_gt = size(curImg,1)*squeeze(phisT(g,:,1:2))/size(curImg_orig,1);
                        clf; imagesc2(curImg);
                        %     hh = quiver2(xy_gt,xy_pred-xy_gt,0,'m-','LineWidth',2, 'ShowArrowHead','off');
                        %     plotPolygons(xy_gt,'gd','LineWidth',2);
                        plotPolygons(xy_pred,'r.','LineWidth',2);
                        %     showCoords(xy_pred);
                        %     showCoords(xy_gt);
                        drawnow
                        pause;
                    end
                end
                %%
                if strcmp(learningType,'nolearn')
                    model.w = [1 .1 1];
                else
                    %% use structured learning
                    % profile off
                    param.use_pairwise_scores = 1;
                    param.use_appearance_feats = 1;
                    %                     profile on
                    param.phase = 'train';
                    %             profile on
                    model = svm_struct_learn(' -c .1 -o 2 -v 2 -w 4', param) ;
                    %                         profile viewer
                end
                %             profile viewer
                %             [gts,preds,stats] = apply_to_imageset(IsT(tt),phisT(tt,:,:),model,param,kp_sel,learningType,true);
                save(resPath,'model','param');
                
            end
            load(resPath);
            benchmarkResPath = strrep(resPath,'.mat','_bench.mat');
            if doBenchmark && (~exist(benchmarkResPath,'file'))
                test_subset = 1;
                nTest = length(IsT);
                tt = 1:test_subset:nTest;
                %                 tt =191
                load(resPath);
                %                 param.rotations = [0 -15 -30];
                %
                param.rotations = 0;
                %                 profile off
                %                 desiredLocs = [20 18;46 17; 33 44];
                %                 param.pairwise_scores = make_dummy_pairwise_scores(param,desiredLocs);
                param.rotations = 0;
                uu = 20;
                param.rotations =-uu:uu:uu;
                param.toFlip = false;
                %                 model.w = [1 .1];
                param.phase = 'test';
                [gts,preds,stats] = apply_to_imageset(IsT(tt),phisT(tt,:,:),model,...
                    param,kp_sel,learningType,true);
                %%
                for v = .8:.1:1.3
                    I = imread('C:\Users\amirro\Desktop\tmp\applauding_001_face1.jpg');
                    r = [1 1 fliplr(size2(I))];
                    I = cropper(I,round(inflatebbox(r,v,'both',false)));
                    [gts,preds,stats] = apply_to_imageset({I},[],model,...
                        param,kp_sel,learningType,true);
                end
                %%
                %                 profile viewer
                iExp = iExp+1;
                expResults(iExp).name = resPath;
                expResults(iExp).params = param;
                expResults(iExp).model = model;
                expResults(iExp).stats = stats;
            end
        end
    end
end
% profile viewer
%%

%%
if (doBenchmark)
    addpath('D:\datasets\cofw\prettyPlot');
    all_stats = [expResults.stats];
    z = (cat(1,all_stats.mean_error));
    %colors = {'r-s','g-d','b-d','r-o','g-o','b-o','r-s','g-s','b-s'};
    %colors = {'r','g','b','c','m','y','k','y'
    colors = distinguishable_colors(length(expResults));
    %   figure
    %   image(reshape(c,[1 size(c)]))
    figure(2);
    clf; hold on;
    bins = 0:.001:.1;
    for t = length(expResults):-1:1
        curStats = expResults(t).stats;
        [a,b] = hist(curStats.mean_error, bins);
        a = cumsum(a)/sum(a);
        plot(b,a,'Color',colors(t,:),'LineWidth',2);
    end
    legend(fliplr({'minimal_64','partial_64','full_64','minimal_80','partial_80','full_80','minimal_100','partial_100','full_100'}),...
        'Interpreter', 'none');
    xlabel('Mean Normalized Error');
    ylabel('Fraction of Images');
    grid on;
end



