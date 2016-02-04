function analyze_errors(ff_mine,ff_sanity)

clf;
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

%my_xyz = ff_mine.xyz(ff_mine.dists<30000,:);
my_xyz = ff_mine.xyz;
% figure,hist(ff_mine.dists,50)
gt_xyz = ff_sanity.xyz;

[mm,im] = min(l2(my_xyz,gt_xyz).^.5,[],2);
% im = im(:,1); 
% plot3(ff_sanity.xyz(:,1),ff_sanity.xyz(:,2),ff_sanity.xyz(:,3),'g.');
 
subplot(2,3,1); hold on;
plot3(my_xyz(:,1),my_xyz(:,2),my_xyz(:,3),'r.');
plot3(gt_xyz(im,1),gt_xyz(im,2),gt_xyz(im,3),'g.');
diff_3 = gt_xyz(im,:)-my_xyz;
quiver3(my_xyz(:,1),my_xyz(:,2),my_xyz(:,3),diff_3(:,1),diff_3(:,2),diff_3(:,3),0);
title('recon. points vs ground truth points');
legend({'recon.','gt'});

subplot(2,3,2),hist(diff_3(:,3),50);title('z error distribution');

%% analyze errors : for each computed match, find nearest neighbor of source and corresp. destination
% ggg = ff_mine.dists<30000;
ggg = 1:size(ff_mine.xy_src,1);
my_src = ff_mine.xy_src_rect(ggg,:);
my_dst = ff_mine.xy_dst_rect(ggg,:);
gt_src = ff_sanity.xy_src_rect;
gt_dst = ff_sanity.xy_dst_rect;
[mm,im] = sort(l2(my_src,gt_src).^.5,2,'ascend');
m = mm(:,1);
im = im(:,1);
goods = m < 1;
fprintf('number of total matches: %d\n',length(m));
fprintf('number of sources near ground-truth: %d\n', nnz(goods));
my_src = my_src(goods,:);
my_dst = my_dst(goods,:);
gt_src = gt_src(im(goods),:);
gt_dst = gt_dst(im(goods),:);

assert(all(vec_norms(my_src-gt_src) < 1));

dists = vec_norms(my_dst-gt_dst);
[dists_to_gt,idists] = sort(dists,'descend');
subplot(2,3,3); hist(dists_to_gt,100); title('error distribution (pixel distance)');

I1Rect = ff_mine.I1Rect;
I1Rect_ = ff_sanity.I1Rect;
assert(all(I1Rect(:)==I1Rect_(:)));

Z_mine = make_disparity(I1Rect,ff_mine.xy_src(ggg,:),ff_mine.xy_dst(ggg,:));
mask = I1Rect>10/255;

% x2(Z_mine.*mask);
% plotPolygons(ff_mine.xy_src_rect,'r.');

Z_gt = make_disparity(I1Rect,ff_sanity.xy_src,ff_sanity.xy_dst);
% figure(2);
subplot(2,3,4);imagesc2(Z_mine.*mask);title('our disparity');
subplot(2,3,5);imagesc2(Z_gt.*mask);title('true disparity');


end

