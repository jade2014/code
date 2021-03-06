function sampleData = collectSamples(conf, fra_db,cur_set,params)
dlib_landmark_split;
tic_id = ticStatus('extracting training features...',.5,.5,false);
samples = {};
% if nargin < 6
%     debug_jump = 1;
% end
debug_jump = params.debug_jump;
phases = params.phases;
for iImage = 1:debug_jump:length(cur_set)
% for iImage = 1

    %     iImage
    imgInd = cur_set(iImage);
    imgData = fra_db(imgInd);
    %     faceBox = imgData.faceBox;
    I = getImage(conf,imgData);
    [I_sub,~,mouthBox] = getSubImage2(conf,imgData,~params.testMode);
    %[mouthMask,curLandmarks] = getMouthMask(I_sub,mouthBox,imgData.Landmarks_dlib,dlib,imgData.isTrain);
    [mouthMask,curLandmarks] = getMouthMask(imgData,I_sub,mouthBox,imgData.isTrain);
    [groundTruth,isValid] = getGroundTruthHelper(imgData,params,I,mouthBox);
    if ~isValid && ~params.testMode
        warnString = sprintf('invalid image found : %d --> %s\nskipping this image!!!',...
            imgInd,imgData.imageID);
        params.logger.warn(warnString,'collectSamples');        
%         warning(sprintf('invalid image found : %d --> %s\nskipping this image!!!',...
%             imgInd,imgData.imageID));
    else
        % coarse stage:
        if params.testMode
            imgData.action_obj.active = imgData.action_obj.test;
        else
            imgData.action_obj.active = imgData.action_obj.train;
        end
        imgData.I = I;
        imgData.I_sub = I_sub;
        imgData.mouthMask = mouthMask;
        imgData.curLandmarks = curLandmarks;
        prev_candidates = [];       
        P_prev = [];
        for iPhase = 1:length(phases)            
            curPhase = phases(iPhase);
            P = curPhase.alg_phase;
            candidates = P.getCandidates(imgData,prev_candidates);
            if isempty(candidates.masks)
                params.logger.warn(['no candidates found for image ' imgData.imageID ],'collectSamples');
                continue
            end
                                    
            if iPhase>1 & ~isempty(P_prev.classifiers)
                current_candidates = P_prev.pruneCandidates(imgData, currentFeats, candidates,P_prev,imgInd)
                P_prev.pruneCandidates(imgData,prev_candidates,...
                currentFeats,candidates,P_prev,imgInd)
%                                                             pruneCandidates(imgData,prev_candidates,currentFeats,candidates.masks,P_prev,imgInd);
%                                           pruneCandidates(imgData,current_candidates,prev_candidates,current_feats,imgInd)
            end
            [regions,labels,ovps] = P.sampleRegions(candidates.masks,...
                groundTruth);
            prev_candidates = regions;
            currentFeats = P.extractFeatures(imgData,regions);
            P_prev = P;
        end
        
        curSamples.imgInd = imgInd;
        curSamples.regions = regions;
        curSamples.labels = labels;
        curSamples.feats = currentFeats;
        curSamples.ovps = ovps;
        samples{end+1} = curSamples;
    end
    tocStatus(tic_id,iImage/length(cur_set));
end

sampleData = aggregateSamples(fra_db,samples);
%function [feats,labels,regions,inds] = aggregateSamples(fra_db, samples)
function sampleData = aggregateSamples(fra_db, samples)
sampleData = struct('inds',{},'feats',{},'labels',{},'regions',{});
labels = {};
feats = {};
inds = {};
regions = {};
for t = 1:length(samples)
    curSamples = samples{t};
    imgInd = curSamples.imgInd;
    curClassLabel = fra_db(imgInd).classID;
    curLabels = curSamples.labels;
    curOvps = curSamples.ovps;
    curLabels(curLabels==1) = curClassLabel;
    inds{t} = ones(1,length(curLabels))*imgInd;
    labels{t} = curLabels;
    ovps{t} = curOvps;
    regions{t} = row(curSamples.regions);
    %feats{t} = [curSamples.f_int;curSamples.f_app;curSamples.f_shape]
    feats{t} = curSamples.feats;
    %[curSamples.f_int;curSamples.f_app;curSamples.f_shape]
end
inds = cat(2,inds{:});
feats = cat(2,feats{:});
labels = cat(1,labels{:});
ovps = cat(1,ovps{:});
regions = cat(2,regions{:});
sampleData(1).inds = inds;
sampleData.feats = feats;
sampleData.labels = labels;
sampleData.ovps = ovps;
sampleData.regions = regions;