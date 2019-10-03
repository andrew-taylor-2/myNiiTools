function mask_fib(mask_fn,fib_fn,out_fn)
% ugly script, but it works. Much of the reading and writing methods are
% those suggested by frank yeh of DSI studio (http://dsi-studio.labsolver.org/)
%


%----
% Sanitize input
%----

gunziped=@(x) x(1:end-3);
paren=@(x,varargin) x(varargin{:});

if contains(mask_fn,'.gz')
    gunzip(mask_fn)
    mask_fn=gunziped(mask_fn);
end

%----
% Load
%----

mask_hdr=spm_vol(mask_fn);
mask_img=spm_read_vols(mask_hdr(1));
if size(mask_img,4)~=1; warning('your input mask is 4d -- function is intended to be used with 3d data');end
mask_img(mask_img~=0)=1; % binarize. this is idempotent

%----
% Image must be LPS -- that's all DSI studio takes, apparently. So we
%     probably need to flip the mask images
%----

%flip a/p if needed
if mask_hdr(1).mat(6)>0
    mask_img=mask_img(:,size(mask_img,2):-1:1,:);
end

%flip l/r if needed
if mask_hdr(1).mat(1)>0
    mask_img=mask_img(size(mask_img,1):-1:1,:,:);
end

%flip i/s if needed
if mask_hdr(1).mat(11)<0
    mask_img=mask_img(:,:,size(mask_img,1):-1:1);
end

fib = load(fib_fn,'-mat');


%----
% Find size of each datatype -- "fa" and "odf" have constant number of elements,
%     but the number of fa/odf variables varies
%----

max_fib = 0;
for i = 1:30
    if isfield(fib,strcat('fa',int2str(i-1)))
        max_fib = i;
    else
        break;
    end
end

max_odf = 0;
for i = 1:30
    if isfield(fib,strcat('odf',int2str(i-1)))
        max_odf = i;
    else
        break;
    end
end

%----
% Mask only relevant entries -- "FA" holds information for every voxel, whether elements are zero
%     or nonzero. but ODF only contains information from nonzero. So we mask ODF based on the
%     pattern of nonzeros in FA
%----


nn=size(fib.odf0,2); %size of chunks

fa_nz_vector=fib.fa0~=0;
fa_nz_linear_indices=find(fib.fa0~=0); %inds of original
mask_img_vector=reshape(mask_img,1,[]);

deletion_vector=fa_nz_vector & ~mask_img_vector;
deletion_linear_indices=find(deletion_vector); %"missing" inds
disp(['numel deleted = ' num2str(sum(deletion_vector(:)))])

%do the magic
logical_for_odf_deletion=ismember(fa_nz_linear_indices,deletion_linear_indices);


%----
% Build ODF vars -- most of this portion comes straight from http://dsi-studio.labsolver.org/,
%     which is why they're so ugly
%----

odf=[];
for i = 1:max_odf
    %build odf var
    eval(strcat('odf =  cat(2,odf,fib.odf',int2str(i-1),');'))
    strcat('odf =  cat(2,odf,fib.odf',int2str(i-1),');')

end

if size(odf,2)~=sum(fib.fa0(:)~=0)
    warning('odf and fa number of elements is not the same')
end

odf(:,logical_for_odf_deletion)=[];
for i = 1:max_fib
    eval(strcat('fa',int2str(i-1),'=fib.fa',int2str(i-1),';'));
    strcat('fa',int2str(i-1),'=fib.fa',int2str(i-1),';')
    eval(strcat('dir',int2str(i-1),'=fib.dir',int2str(i-1),';'));
    strcat('dir',int2str(i-1),'=fib.dir',int2str(i-1),';')
    eval(strcat('fa',int2str(i-1),'(1,deletion_vector)=0;',';'))
    strcat('fa',int2str(i-1),'(1,deletion_vector)=0;')
    eval(strcat('dir',int2str(i-1),'(:,deletion_vector)=0;',';'))
    strcat('dir',int2str(i-1),'(:,deletion_vector)=0;')
%     eval(strcat('clear odf',int2str(i-1))) % unnecessary -- so far, we
%     haven't defined an odf_i outside of fib.odf_i
%     strcat('clear odf',int2str(i-1))
end

%----
% Rewrite ODF -- how many chunks do we need?
%----

num_odf_vars_needed=ceil(numel(odf)/(nn*size(fib.odf0,1)));


for i=1:num_odf_vars_needed
    starting_index=(i-1).*nn+1;
    ending_index=(i).*nn;
    if i~=num_odf_vars_needed
        eval(strcat('odf',int2str(i-1),'=odf(:,starting_index:ending_index);'));
        strcat('odf',int2str(i-1),'=odf(:,starting_index:ending_index);')
    elseif i==num_odf_vars_needed
        eval(strcat('odf',int2str(i-1),'=odf(:,starting_index:end);')); %could just find the remainder instead of doing 'end', but whatever
        strcat('odf',int2str(i-1),'=odf(:,starting_index:end);')
    end
end

%----
% Save vars -- a .fib file is just a Matlab workspace
%----

odf_faces=fib.odf_faces;
odf_vertices=fib.odf_vertices;
dimension=fib.dimension;
voxel_size=fib.voxel_size;

clear odf
clear mask_img_vector
clear fa_nz_vector
clear deletion_vector
clear mask_img
clear max_fib
clear i
clear starting_index
clear ending_index
clear fib
clear deletion_vector
clear deletion_linear_indices
clear fa_nz_linear_indices
clear logical_for_odf_deletion
clear num_odf_vars_needed
clear nn
clear gunziped
clear mask_fn
clear paren
clear ans
clear fib_fn
clear max_odf
clear mask_hdr

% you could just do multiple save(...,'-append') statements wrapped in eval(...) to refer to
%     the variable number of odf,fa, etc variables

save(out_fn,'-v4')
end
