function QC_text=spm_reslice_dont_move_data(target_fn,source_fn,moved_source_fn,varargin)
%reslice source_fn to dimensions of target_fn. This ensures the least
%movement of underlying data, but does not ensure that world coordinates
%will match up across target and moved source image. In fact, they probably
%will not.
%
%NOTE: all operations are based on the first volume of target_fn and
%source_fn.
%
%varargin{1}, if defined, will be used as QC output folder:
%spm_reslice_dont_move_data(target_fn,source_fn,moved_source_fn,QC_folder)

%NOTE: If you're writing to an existing filename, there might be extra
%volumes after the ones you've written with this function. Perhaps there
%should be a warning about rewriting

%andrew will use
%QC_output_folder=varargin{1}='/Users/andrew/re/QC_dump';

target_fn=char(target_fn);
source_fn=char(source_fn);
moved_source_fn=char(moved_source_fn);

target_hdr=spm_vol(target_fn);
% target_img=spm_read_vols(target_hdr); % unnecessary. we only need
% metadata from target

source_hdr=spm_vol(source_fn);
source_img=spm_read_vols(source_hdr);

srcmat=spm_imatrix(source_hdr(1).mat); %this and the line below do assume that the first volume's ".mat" field is representative of each image. This is a super reasonable assumption tho
trgmat=spm_imatrix(target_hdr(1).mat);

newmat=spm_matrix([trgmat(1:6) srcmat(7:9) 0 0 0]); %keep target translations, rotations. keep source voxel size. no shears. If there are shears, this will remove them.

dummy_source_hdr=source_hdr;
for i=1:length(source_hdr)
    dummy_source_hdr(i).mat=newmat; 
    dummy_source_hdr(i).private.mat=newmat; 
    dummy_source_hdr(i).private.mat0=newmat; 
end

[dummy_source_hdr.fname]=deal(moved_source_fn); %moved_source_fn should probably be defined in relation to source
for i=1:length(source_hdr); spm_write_vol(dummy_source_hdr(i),source_img(:,:,:,i)); end %write
flaggs.which=[1 0];
flaggs.prefix='r';
flaggs.interp=1; %trilinear interpolation
spm_reslice({target_fn,moved_source_fn},flaggs)

QC_text1=['''' source_fn ''' has been resliced to the dimensions of ''' target_fn ''' and written as a new file, ''' moved_source_fn '''.' '\n'];
fprintf(QC_text1)
QC_text=char(QC_text1);

%% create a 2 volume QC image to make sure the underlying source data didn't move outside the bounding box
%this part is just for QC and isn't central to the function at all
try
if exist('varargin','var') && ~isempty(varargin)
    if numel(varargin)>1
        warning('too many inputs. only using the first optional argument')
    end
    
    QC_output_folder=varargin{1};
    
    UID=dicomuid; %generate a uniquely identifying string
    
    source_QC_hdr=spm_vol([source_fn ',1']); %just go back to the original filenames to see if the write went well
    rsource_QC_hdr=spm_vol([moved_source_fn ',1']);
    
    source_QC_img=spm_read_vols(source_QC_hdr);
    rsource_QC_img=spm_read_vols(rsource_QC_hdr);
    
    source_QC_hdr.fname=fullfile(QC_output_folder, [UID '.original.nii']);
    rsource_QC_hdr.fname=fullfile(QC_output_folder, [UID '.resampled.nii']);
    
    spm_write_vol(source_QC_hdr,source_QC_img) % we already have source data loaded into this function, so we might as well use it here
    spm_write_vol(rsource_QC_hdr,rsource_QC_img)
    
    QC_text2=['QC volumes have been generated at ''' QC_output_folder ''' with unique identifier ''' UID ''''];
    fprintf(QC_text2)
    
    QC_text=char(QC_text1,QC_text2); %note that this will not include QC bit if this try block has errors
end
catch
    warning('QC portion of function did not complete without errors')
end
end