% ------------------------------------------------------------------------ 
%  Copyright (C)
%  Universitat Politecnica de Catalunya BarcelonaTech (UPC) - Spain
%  University of California Berkeley (UCB) - USA
% 
%  Jordi Pont-Tuset <jordi.pont@upc.edu>
%  Pablo Arbelaez <arbelaez@berkeley.edu>
%  June 2014
% ------------------------------------------------------------------------ 
% This file is part of the MCG package presented in:
%    Arbelaez P, Pont-Tuset J, Barron J, Marques F, Malik J,
%    "Multiscale Combinatorial Grouping,"
%    Computer Vision and Pattern Recognition (CVPR) 2014.
% Please consider citing the paper if you use this code.
% ------------------------------------------------------------------------

function ms_struct = ms_matrix2struct( ms_matrix )
    ms_struct = struct('parent',{},'children',{}); % changed by amir, 20/10/2014, to avoid crash from returning nothing
    for ii=1:size(ms_matrix,1)
        ms_struct(ii).parent = ms_matrix(ii,end); %#ok<AGROW>
        children = ms_matrix(ii,1:end-1);
        children(children==0) = [];
        ms_struct(ii).children = children; %#ok<AGROW>
    end
end
