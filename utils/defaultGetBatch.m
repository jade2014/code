
function [im, labels] = defaultGetBatch(imdb, batch)
% --------------------------------------------------------------------
im = imdb.images.data(:,:,:,batch) ;
labels = imdb.images.labels(:,:,:,batch) ;
% labels = imdb.images.labels(1,batch) ;
% if rand > 0.5, im=fliplr(im) ; end
end
