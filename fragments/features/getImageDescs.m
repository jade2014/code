function [ descs ] = getImageDescs(VOCopts,globalOpts,imageID)
%GETIMAGEDESCS Summary of this function goes here
%   Detailed explanation goes heretinyImages = im2single(tinyImages);
A = zeros(32,32,3,'single');
dims = size(globalOpts.descfun(A));

boxesFileName = sprintf(VOCopts.exfdpath,[imageID '_boxes']);
load(boxesFileName);
tinyImagesFileName = sprintf(VOCopts.exfdpath,[imageID '_tinyimages']);
load(tinyImagesFileName);

descs = zeros(size(boxes,1),dims(1),dims(2),'single');
tinyImages = im2single(tinyImages);
z = zeros(1,size(boxes,1));

for k = 1:size(tinyImages,1)
    if (mod(k,20)==10)
        disp(k);
    end
    T = squeeze(tinyImages(k,:,:,:));
    
    descs(k,:,:) = globalOpts.descfun(T);
end
end

