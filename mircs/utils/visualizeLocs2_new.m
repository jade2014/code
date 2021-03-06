function [p,p_mask] = visualizeLocs2_new(conf,ids,locs,varargin)
%VISUALIZELOCS2 crop patches around detector hits
% VISUALIZELOCS2(conf,ids,locs,varargin)
%
% VISUALIZELOCS2(conf,ids,locs,param1,value1,param2,value2,...)

ip = inputParser;
ip.addParamValue('add_border',false,@islogical);
ip.addParamValue('inflateFactor',1,@isnumeric);
ip.addParamValue('draw_rect',false,@islogical);
ip.addParamValue('height',64,@isnumeric);
% ip.addParamValue('saveMemory',false,@islogical);
ip.parse(varargin{:});
add_border = ip.Results.add_border;
%saveMemory = ip.Results.saveMemory;
draw_rect = ip.Results.draw_rect;
inflateFactor = ip.Results.inflateFactor;
height = ip.Results.height;


if (iscell(ids{1}))
    p = {};
    p_mask = {};
    for k = 1:length(ids)
        [a,b] = visualizeLocs2(conf,ids{k},cat(1,locs{k}{:}),height,inflateFactor,add_border,draw_rect);
        p{k} = a;
        p_mask{k} = b;
    end
    return;
end


p = {};
% loadedImages = cell(1,length(ids));
% loaded_rects = zeros(length(ids),4);

for k = 1:size(locs,1)
    k
    id_index = locs(k,11);
    imageID = ids{id_index};
    
    if (ischar(imageID))
        %         if (~saveMemory)
        %             II = (loadedImages{id_index});
        %         end
        %         if (saveMemory || isempty(II))
        [I,xmin,ymin,xmax,ymax] = toImage(conf,getImagePath(conf,imageID),1);
        if (conf.not_crop)
            xmin = 0;
            ymin = 0;
        end
        %             if (~saveMemory) loadedImages{id_index} = (I); end
        %             loaded_rects(id_index,:) = [xmin ymin xmax ymax];
        %         else
        %             I = II;
        %             xmin = loaded_rects(id_index,1);
        %             ymin = loaded_rects(id_index,2);
        %             xmax = loaded_rects(id_index,3);
        %             ymax = loaded_rects(id_index,4);
        %         end
        
        size_ratio = (ymax-ymin+1)/conf.max_image_size;
        rect = inflatebbox(locs(k,1:4),inflateFactor);
        if (size_ratio > 1) % loc has been taken from cropped image
            rect = rect*size_ratio;
        end
        
        rect([1 3]) = rect([1 3]) + xmin;
        rect([2 4]) = rect([2 4]) + ymin;
        
    else
        I = imageID;
        rect = locs(k,1:4);
        xmin = 1;ymin = 1;xmax = size(I,2);ymax = size(I,1);
    end
    [I_cropped,I_mask] = cropper(im2uint8(I),double(round(rect)));
    if (draw_rect)
        close all;
        imshow(I);
        hold on;
        plotBoxes2(rect([2 1 4 3]),'Color','g','LineWidth',3);
        plotBoxes2([ymin xmin ymax xmax],'Color','m','LineWidth',1);
        if (locs(k,conf.consts.FLIP))
            title('flip');
        else
            title('no flip');
        end;
        pause;
    end
    if (locs(k,conf.consts.FLIP))
        I_cropped = flip_image(I_cropped);
    end
    %I_cropped = myResize(I_cropped,height,'bicubic');
    if (~isempty(height))
        I_cropped = imresize(I_cropped,[height NaN],'bicubic');
    end
    I_mask = imresize(I_mask,[height NaN],'nearest');
    if (add_border && ischar(imageID))
        if (~isempty(strfind(imageID,conf.classes{conf.class_subset})))
            I_cropped =addBorder(I_cropped,3,[0 255 0]);
        else
            I_cropped =addBorder(I_cropped,3,[255 0 0]);
        end
        I_cropped =addBorder(I_cropped,1,[0 0 0]);
    end
    
    p{k} = im2uint8(I_cropped);
    if (nargout == 2)
        p_mask{k} = I_mask;
    end
end