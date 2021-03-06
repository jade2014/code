
addpath('~/code/SGE/');

defaultOpts;

test_images = textread(sprintf(globalOpts.VOCopts.imgsetpath,globalOpts.VOCopts.testset),'%s');
train_images = textread(sprintf(globalOpts.VOCopts.imgsetpath,globalOpts.VOCopts.trainset),'%s');

all_images = [train_images;test_images];

code = ['cd /home/amirro/code/fragments; tt_0_1x2_1000;'...
    'extract_boxes(globalOpts,img)'];
images = all_images;


L = 100;
c = mod(1:length(all_images),L)+1;
for k = 1:L
    images{k} = all_images(c==k);
    %     images_(c==k);
end


run_parallel(code, 'img',images,'-cluster', 'mcluster01');
% images = (length(train_images)+1):length(all_images);

% run_parallel(code, 'img',mat2cell(images,1,ones(1,length(images))),'-cluster', 'mcluster01');


