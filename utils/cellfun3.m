function res = cellfun3(funer,structy,dim_to_cat)
% apply function on each element of cell array and concat results
% to matrix along given dimension

if nargin < 2
    error('Not enough arguments to cellfun3\n');
end
if nargin < 3
    dim_to_cat = 1;
end
res = cellfun2(funer, structy);
res = cat(dim_to_cat,res{:});