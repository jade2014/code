function collectResults(globalOpts,test_images,cls,getMax,suffix,iter)
% This is used to concatenate the per-image files
% create by applyModel to a format acceptable by PASCAL's
% function for evaluation avg. precision.

if (~exist('cls','var') || isempty(cls))
    cls = 1:length(globalOpts.VOCopts.classes);
end

if (nargin < 4)
    getMax = 0;
end

if (exist('useArgMax','var'))
    useArgMax = 0;
end

nClasses = length(cls);

openFiles = true;
if (openFiles && ~globalOpts.debug)
    fids = cell(1,nClasses);
    fclose all;
    for iClass = 1:nClasses
        cls_ = globalOpts.VOCopts.classes{cls(iClass)};
        fPath = sprintf(globalOpts.VOCopts.detrespath,[globalOpts.exp_name '_comp3' suffix],cls_);
        if (exist(fPath,'file'))
            delete(fPath);
        end
        fids{iClass}=fopen(fPath,'w');
    end
end
count_ = 0;
for k = 1:length(test_images)
    %     k
    currentID = test_images{k};
    resultPath = getResultsPath(globalOpts,iter);
    fPath = fullfile(resultPath, [currentID '.txt']);
    
    if (~exist(fPath,'file'))
        warning(['results for image ' currentID ' don''t exist']);
        continue;
    end
    count_ = count_ + 1
    % read current file
    fid = fopen(fPath);
    nResults = 100;
    A = textscan(fid,'%s %f %f %f %f %f %d',nResults); %TODO - this is 
    % done only to speed things up and in practice will harm the PD. 
    fclose(fid);
    
    bboxes_t = [A{3:6}];
    %nboxes_t = size(bboxes_t,1)/20;
    %bboxes_t = bboxes_t(1:nboxes_t,:);
    %     if (globalOpts.removeOverlappingDetections)
    %         b_overlap = boxesOverlap(bboxes_t);
    %         overlaps_t = max(b_overlap,...
    %             b_overlap');
    %     end
    all_scores = A{2};
    %
    %     P = reshape(all_scores,[],20);
    %     [mm,imm] = max(P,[],2);
    %
    
    for iClass = 1:nClasses
        currentClass = cls(iClass);
        
        ids = A{1};
        
        ;%[A{3:6}]';
        imageEstClass = A{7};
        
        
        % sort boxes according to score and remove overlaps.
        
        f = imageEstClass == currentClass;
        bboxes = bboxes_t(f,:);
        
        if (globalOpts.removeOverlappingDetections)
            b_overlap = boxesOverlap(bboxes);
            overlaps_t = max(b_overlap,...
                b_overlap');
        end
        
        scores = all_scores(f);
        %         bboxes = bboxes(:,f);
        imageEstClass = imageEstClass(f);
        ids = ids(f);
        
        if(getMax)
            
            [~,im] = max(scores);
            scores =scores(im);
            imageEstClass = imageEstClass(im);
            bboxes = bboxes(im,:);
        else
            
            [scores,iscores] = sort(scores,'descend');
            
%             ddd = 100;
%             iscores = iscores(1:ddd);
%             scores = iscores(1:ddd);
            bboxes = bboxes(iscores,:);
            imageEstClass = imageEstClass(iscores);
            
            if (globalOpts.removeOverlappingDetections)
                
                % sort the rows/cols of the overlap matrix as well...
                overlaps = overlaps_t(:,iscores);
                overlaps = overlaps(iscores,:);
                
                bads = bad_bboxes(bboxes(:,[2 1 4 3]),globalOpts) | scores==-1000;
                
                scores = scores(~bads);
                bboxes = bboxes(~bads,:);
                imageEstClass = imageEstClass(~bads);
                
                overlaps = overlaps(:,~bads);
                overlaps = overlaps(~bads,:);
                
                nBoxes = size(bboxes,1);
                
                %         if (globalOpts.removeOverlappingDetections)
                
                range_ = 1:min(inf,nBoxes);
                bboxes = bboxes(range_,:);
                imageEstClass = imageEstClass(range_);
                scores = scores(range_);
                nBoxes = size(bboxes,1);
                
                [toIgnore,toRemove]= (find(overlaps >= .3));
                
                goods_ = toRemove > toIgnore; % only remove those with
                % a higher previous score...
                toIgnore = toIgnore(goods_);
                toRemove = toRemove(goods_);
                
                removed = false(1,nBoxes);
                for iRemove = 1:length(toRemove)
                    if (~removed(toIgnore(iRemove)))
                        removed(toRemove(iRemove)) = true;
                    end
                end
                
                toRemove = find(removed);
                
                keep = setdiff(1:nBoxes,toRemove);
                
                scores = scores(keep);
                bboxes = bboxes(keep,:);
                imageEstClass = imageEstClass(keep);
            end
        end
        
        %         end
        
        if (globalOpts.debug)
            
            draw = 0;
            plot = 1;
            im = imread(getImageFile(globalOpts,currentID));
            if (draw)
                tops = find(imageEstClass == currentClass);
                [~,is] = sort(scores(tops),'descend');
                
                clf;
                imshow(im);title(globalOpts.VOCopts.classes(currentClass));
                hold on;
                ddd = 1;
                plotBoxes2(bboxes(tops(is(1:min(ddd,length(is)))),[2 1 4 3]),...
                    'Color','g','LineWidth',2);
                disp(scores(tops(is(1:min(ddd,length(is))))));
            end
            
            if (plot)
                tops = find(imageEstClass == currentClass);
                sz = size(im);
                im = imread(getImageFile(globalOpts,currentID));
                clf;
                imshow(im);title(globalOpts.VOCopts.classes(currentClass));
                %Z = plotBoxes(sz,bboxes(tops,[2 1 4 3]),scores(tops).*(scores(tops)>0));
                Z = plotBoxes(sz,bboxes(tops,[2 1 4 3]),scores(tops));
                R = im(:,:,1);
                Z = Z/10;%max(Z(:));
                II = 0.5*im2double(rgb2gray(im));                
                Z = cat(3,Z.^2+II,II,II);
                imshow(Z,[]);
            end
            pause;
            
        end
        
        
        % now sort according to imageEst class for faster file io
        %     [imageEstClass,ii] = sort(imageEstClass);
        %     scores = scores(ii);
        %     bboxes = bboxes(:,ii);
        
        
        [cols,rows,~] = BoxSize(bboxes);
        iminfo = imfinfo(getImageFile(globalOpts,currentID));
        rows = rows/iminfo.Height;
        cols = cols/iminfo.Width;
        
        
        if (openFiles && ~globalOpts.debug)
            fid = fids{iClass};
            for j=1:length(scores)
                %                 if (imageEstClass(j) < nClasses+1) 
                fprintf(fid,'%s %f %f %f %f %f %f %f\n',currentID,scores(j),bboxes(j,:),rows(j),cols(j)); % add height,width
            end
            %             fprintf(fid,'%s %f %f %f %f %f\n',ids,scores,{bboxes});
            %             end
        end
    end
end
fclose all;
end