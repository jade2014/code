% Run code in parallel on the SGE cluster.
% Pass different variable values to each job.
%
% This function is similar to run_parallel, but allows limiting the number
% of jobs. This is done by aggregating multiple job ids into batches. Each
% job will execute an entire batch of job ids within a single Matlab
% session, using a regular for loop over the job ids.
% This introduces the following limitations:
%   Variable names beginning with SGE_INTERNAL_ are reserved, and may not
%   be used as variable names in the script.
%   As each job may loop over several job ids, script should not assume a
%   clear workspace. All variables should be initialized.
%
% This function does the following:
%   - Save the variables into a temporary file
%   - Create a wrapper script for the code, that first loads the variables
%       and chooses their value according to the job id
%   - Run the script in parallel (one job per set of variable values)
%   - Delete the temporary variables file
%
% Note:
%   Can be used from any linux workstation.
%   Requires ssh connection to cluster without password.
%
% Syntax:
%   run_parallel_batches(code, varname1, value1, varname2, value2, ...)
%   run_parallel_batches(..., '-cluster', cluster_name)
%   run_parallel_batches(..., '-jobs', max_jobs)
%
% Input:
%   code -
%       Code to run, as string.
%   varname -
%       Variable name
%   value -
%       Variable value.
%       If this is a cell array, each job will get a value of one cell.
%       Otherwise this value will be replicated for each job.
%       All cell arrays should have the same number of elements.
%       The number of jobs is determined according to the size of the cell
%       arrays.
%   cluster_name (optional) -
%       Name of SGE cluster to use.
%       Default is mcluster01.
%   max_jobs (optional) -
%       Maximum number of parallel jobs that will be created.
%       If specified, then each job may iterate multiple cell entries
%       (using a serial for loop).
%
% Output:
%   qsub log files are saved as
%   ~/sge_parallel/run_matlab_script.[e|o][task_id].[job_id]
%
%
% Last edit: Nimrod Dorfman 6/12/2011
% 
function run_parallel_batches(code, varargin)

% temp file for saving variables
% note: filename uses milisec time, but uniqueness is not checked.
data_file = sprintf('~/sge_parallel/sge_parallel_data_%s.mat', datestr(now, 'yyyymmddHHMMSSFFF'));

% parse variables and save them
[SGE_INTERNAL_data, SGE_INTERNAL_batches, num_jobs, cluster_name] = parse_vars(varargin);
data_dir = fileparts(data_file);
if ~exist(data_dir, 'dir')
    mkdir(data_dir);
end
save(data_file, 'SGE_INTERNAL_data', 'SGE_INTERNAL_batches');

% generate matlab script for parallel jobs
script = gen_script(code, SGE_INTERNAL_data, data_file);

% run in parallel
if isempty(cluster_name)
    sge_parallel(script, num_jobs);
else
    sge_parallel(script, num_jobs, cluster_name);
end

% delete data file
delete(data_file);



%--------------------------------------------------------------------------
% Parse variables
%
% Convert user variables to a struct where each variable is a field.
% Find number of jobs and verify that all cell values are of same size.
% Parse the special keyword pairs ['-cluster', cluster_name] and
% ['-jobs', max_jobs].
% Use max_jobs (if specified) to limit number of jobs and create batches.
%
% Input:
%   varlist - Cell array of variables passed to the main function,
%       excluding the parallel code.
% Output:
%   data - Struct where each field corresponds to a user variable
%       Field name is variable name, value is variable value.
%   batches - Batches structure as created by create_batches().
%   num_jobs - Number of jobs to run. Determined by size of cell arrays,
%       but can be limited by max_jobs.
%   cluster_name - Name of cluster requested by user. Empty if none.
%--------------------------------------------------------------------------
function [data, batches, num_jobs, cluster_name] = parse_vars(var_list)

cluster_name = [];
max_jobs = inf;
n = numel(var_list);
assert(mod(n, 2) == 0, 'Variables must be specified in name, value pairs');

cell_size = zeros(1, n/2);
for i = 1:2:n
    if strcmpi(var_list{i}, '-cluster')
        % cluster name
        cluster_name = var_list{i+1};
    elseif strcmpi(var_list{i}, '-jobs')
        % max jobs
        max_jobs = var_list{i+1};
    else
        % variable-value pair
        data.(var_list{i}) = var_list{i+1};
        if iscell(var_list{i+1})   % validate cell size
            assert(~isempty(var_list{i+1}), 'Cell variables must contain one element per job. They cannot be empty.');
            cell_size(i) = numel(var_list{i+1});
        end
    end
end

num_jobs = max(1, max(cell_size));
assert(all(cell_size(cell_size > 0) == num_jobs), 'All cell variables must have the same size');

% create batches and limit num_jobs
batches = create_batches(num_jobs, max_jobs);
num_jobs = min(num_jobs, max_jobs);


%--------------------------------------------------------------------------
% Return a struct with information about job ids for each batch
%
% Input:
%   num_jobs - Number of job ids as determined by size of cell arrays.
%   max_jobs - Max number of jobs as specified by the user, inf if none.
% Output:
%   batches.first{j} - first job id for job j
%   batches.last{j} - last job id for job j
%--------------------------------------------------------------------------
function batches = create_batches(num_jobs, max_jobs)

if num_jobs <= max_jobs
    first = 1:num_jobs;
    last = first;
else
    first = ceil(linspace(1, num_jobs+1, max_jobs+1));
    last = first(2:end) - 1;
    first = first(1:end-1);
end
batches.first = num2cell(first);
batches.last = num2cell(last);


%--------------------------------------------------------------------------
% Generate matlab script for parallel jobs
%--------------------------------------------------------------------------
function script = gen_script(code, data, data_file)

% load data
script = sprintf('load %s;', data_file);

% loop over job ids
command = [ ...
    'SGE_INTERNAL_batch = job_id;' ...
    'for job_id = SGE_INTERNAL_batches.first{SGE_INTERNAL_batch}:SGE_INTERNAL_batches.last{SGE_INTERNAL_batch},' ...
    ];
script = [script command];

% choose variable values
names = fieldnames(data);
for i = 1:numel(names)
    if iscell(data.(names{i}))
        command = sprintf('%s = SGE_INTERNAL_data.%s{job_id};', names{i}, names{i});
    else
        command = sprintf('%s = SGE_INTERNAL_data.%s;', names{i}, names{i});
    end
    script = [script command];
end

% add user code
script = [script code];

% close loop over job ids
command = '; end;';
script = [script command];

