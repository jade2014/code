function fcnTrain_action_objects_8_x2_classes(varargin)
%FNCTRAIN Train FCN model using MatConvNet

run matconvnet/matlab/vl_setupnn ;
addpath matconvnet/examples ;
% experiment and data paths

opts.expDir = '/net/mraid11/export/data/amirro//fcn/data/fcn8s-action_obj_8_x2_classes' ;
opts.dataDir = '/net/mraid11/export/data/amirro//fcn/data/fcn32s-action_obj' ;
mkdir(opts.expDir);
mkdir(opts.dataDir);
opts.modelType = 'fcn8s' ;
% opts.sourceModelPath = '/net/mraid11/export/data/amirro//fcn/data/models/imagenet-vgg-verydeep-16.mat' ;
% opts.sourceModelPath = '/net/mraid11/export/data/amirro/matconv_data/pascal-fcn8s-tvg-dag.mat';

opts.sourceModelPath = '/net/mraid11/export/data/amirro//matconv_data/imagenet-vgg-verydeep-16.mat';
[opts, varargin] = vl_argparse(opts, varargin) ;
% experiment setup
opts.imdbPath = fullfile(opts.expDir, 'imdb.mat') ;
opts.imdbStatsPath = [];%fullfile(opts.expDir, 'imdbStats.mat') ;
opts.vocEdition = '12' ;
opts.vocAdditionalSegmentations = true ;
opts.numFetchThreads = 1 ; % not used yet
% training options (SGD)
opts.train.batchSize = 20 ;
opts.train.numSubBatches = 10 ;
opts.train.continue = true ;
opts.train.gpus = 2;%[1 2];
opts.train.prefetch = true ;
opts.train.expDir = opts.expDir ;
opts.train.learningRate = 0.0001 * ones(1,50) ;
opts.train.numEpochs = numel(opts.train.learningRate) ;
opts.train.numEpochs=100;
opts = vl_argparse(opts, varargin) ;

% -------------------------------------------------------------------------
% Setup data
% -------------------------------------------------------------------------

if exist(opts.imdbPath)
  load(opts.imdbPath) ;
else
  load ~/storage/misc/images_and_masks_x2_w_hands.mat
  
  train = find(isTrain);
  val = train(1:3:end);
  test = find(~isTrain);
  train = setdiff(train,val);
  imdb.images = 1:length(images);
  imdb.images_data = images;
  needToConvert = isa(images{1},'double') && max(images{1}(:))<=1;
  if needToConvert
      for t = 1:length(images)
          imdb.images_data{t} = im2uint8(imdb.images_data{t});
      end
  end  
  for t = 1:length(masks)
      m = masks{t};      
      z = m == 0;
      obj = m == 1;
      m = m-1;
      m(z) = 0;
      m(obj) = 2+fra_db(t).classID;
      masks{t} = m;
%       clf; subplot(1,2,1); imagesc2(masks{t}); colorbar;
%       subplot(1,2,2); imagesc2(m); colorbar;
%       dpc
  end
  
  masks = cellfun2(@uint8,masks);
  imdb.labels = masks;
  imdb.nClasses = 7;
  save(opts.imdbPath,'imdb','train','val','test');
end
% -------------------------------------------------------------------------
% Setup model
% -------------------------------------------------------------------------

% Get initial model from VGG-VD-16
opts.nClasses = imdb.nClasses;
net = fcnInitializeModel_action_obj('sourceModelPath', opts.sourceModelPath,'nClasses',imdb.nClasses) ;
if any(strcmp(opts.modelType, {'fcn16s', 'fcn8s'}))
  % upgrade model to FCN16s
  net = fcnInitializeModel16s(net) ;
end
if strcmp(opts.modelType, 'fcn8s')
  % upgrade model fto FCN8s
  net = fcnInitializeModel8s(net) ;
end
stats.rgbMean =[116.6725  111.5917  103.1466]';
net.meta.normalization.rgbMean = stats.rgbMean;
% 
net.meta.classes = {'face','object'};

% -------------------------------------------------------------------------
% Train
% -------------------------------------------------------------------------

% Setup data fetching options
bopts.numThreads = opts.numFetchThreads ;
bopts.labelStride = 1 ;
bopts.labelOffset = 1 ;
bopts.classWeights = ones(1,imdb.nClasses+1,'single') ; % AMIR - was 21.
bopts.rgbMean = stats.rgbMean ;
bopts.useGpu = numel(opts.train.gpus) > 0 ;

getBatchWrapper = @(x) @(imdb,batch) getBatch_action_obj(imdb,batch,x,'prefetch',nargout==0) ;
% Launch SGD
info = cnn_train_dag(net, imdb, getBatchWrapper(bopts), opts.train, ...
  'train', train, ...
  'val', val) ;

% -------------------------------------------------------------------------
function fn = getBatchWrapper(opts)
% -------------------------------------------------------------------------
fn = @(imdb,batch) getBatch_action_obj(imdb,batch,opts,'prefetch',nargout==0) ;
