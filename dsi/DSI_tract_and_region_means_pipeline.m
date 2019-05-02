
%% SECTION III: Tractography Execution

%going in order of just subject name
fibs=dir('<Folder>/final_run/final_dwis/*/*/masked.fib'); %CHANGE; this just finds the "fn_out"s from the end of the last section
pd_n_a='<Box Folder>/Cases/Atlas/pd_n_a.nii'; %CHANGE
label_file='<Folder>/Cases/Atlas/pd_n_a.txt'; %CHANGE;
folder_depth_subs_name=8; %CHANGE; This just specifies how deep into your directory tree is a folder that matches your subject names
dsi_studio_command='/Applications/dsi_studio.app/Contents/MacOS/dsi_studio'; %CHANGE; the location of your dsi studio -- for running dsi commands in terminal
output_dir='<Folder>/final_run/feb_dsi'; %CHANGE

subns=arrayfun(@(x) index_path(fnify(x),folder_depth_subs_name),fibs,'UniformOutput',0); %not sure sorting is actually necessary...
[ssubns,fibsind]=natsortfiles(subns);

diary('<Folder>/final_run/feb_dsi/diary.txt')
for i=1:length(fibs)
    fibb=fnify(fibs(fibsind(i)));
    output_dir_sub=[output_dir filesep ssubns{i}];
    mkdir(output_dir_sub)
    command=[dsi_studio_command ' --action=trk --source=' fibb ' --connectivity=' pd_n_a ' --connectivity_value=count,ncount,ncount2 --seed_count=1000000 --fa_threshold=0.1 --turning_angle=35 --step_size=1 --smoothing=0  --connectivity_type=pass --output=' output_dir_sub '/results.txt --export=stat']
    system(command)
end


%% SECTION IV: Region Means
% SUBSECTION 1: Write each ROI into each subject space, and then use "ana"
% at terminal to find each mean for each metric

%make a directory for this analysis, move fibs there.
[check_fibs,fibs_ind]=natsortfiles({fibs.folder}); % NOTE CONVENTION: SORT BY COHORT THEN SUB NAME (this arises from the fact that the cohort directory is the parent to the subject directory)
mets_str={'fa','dmean','kmean','kax','krad','drad','dax'};

diary
for i=1:length(fibs)
    
    %simple reorganization
    new_dir=[fibs(fibs_ind(i)).folder filesep 'means'];
    mkdir(new_dir)
    fibs_name1=fnify(fibs(fibs_ind(i)));
    met_folder=fibs(fibs_ind(i)).folder;
    fibs_name2=[new_dir filesep 'masked.fib'];
    movefile(fibs_name1,fibs_name2); %annoying to have to use this as opposed to copyfile, but I'm running out of disk space
    
    % run atlas command
    command =[dsi_studio_command ' --action=atl --source=' fibs_name2 ' --atlas=' pd_n_a ' --output=multiple --cmd=roi']
    system(command)
    
    region_files=dir([fibs_name2 '*.nii.gz']);
    if length(region_files)~=376; warning(['length of region files is actually ' num2str(length(region_files))]);end
    for j=1:7 %the length of mets_str
        met_fn=[met_folder filesep mets_str{j} '.nii'];
        met_output_fn=[met_folder filesep mets_str{j} '.nii.statistics.txt'];
        met_folder_nest=[met_folder filesep mets_str{j}];
        mkdir(met_folder_nest)
        for k=1:length(region_files)
            command=[dsi_studio_command ' --action=ana --source=' met_fn ' --region="' fnify(region_files(k)) '" --export=stat'];
            system(command)
            movefile(met_output_fn,[met_folder_nest filesep num2str(k) '.txt'])
        end
    end
end

% SUBSECTION 2: Read the means from the text files into a nicely structured
% variable

%the code above just writes everything. Then I'll have to read things into
%excel.
%could have done this conjoined, but i got it writing while i wrote the
%reading code

tic
for i=1:length(fibs)

    %define things again each loop; if id vectorized I wouldn't have had to do
    %this
    new_dir=[fibs(fibs_ind(i)).folder filesep 'means'];
    fibs_name1=fnify(fibs(fibs_ind(i)));
    met_folder=fibs(fibs_ind(i)).folder;
    fibs_name2=[new_dir filesep 'masked.fib'];
    
    region_files=dir([fibs_name2 '*.nii.gz']);
    if length(region_files)~=376; warning(['length of region files is actually ' num2str(length(region_files))]);end
    for j=1:7
        met_fn=[met_folder filesep mets_str{j} '.nii'];
        met_output_fn=[met_folder filesep mets_str{j} '.nii.statistics.txt'];
        met_folder_nest=[met_folder filesep mets_str{j}];
        for k=1:length(region_files)
%             command=['/Applications/dsi_studio.app/Contents/MacOS/dsi_studio --action=ana --source=' met_fn ' --region="' fnify(region_files(k)) '" --export=stat'];
%             system(command)
%             movefile(met_output_fn,[met_folder_nest filesep num2str(k) '.txt'])
            file_to_read=[met_folder_nest filesep num2str(k) '.txt'];
            temp = regexp(fileread(file_to_read), '\r?\n', 'split'); %split based on newline
            region_strr=paren(curly(curly(regexp(temp{1},'[^|]+|(.+).nii.gz','tokens'),2),1),2:length(curly(curly(regexp(temp{1},'[^|]+|(.+).nii.gz','tokens'),2),1)));%don't ask. %note from later on: what I really meant was '[^|]+|(.+)\.nii\.gz'
            %explanation for above: it looks scary, but it's really just
            %saying: match things that look like a .nii.gz filename with a "|" in it, and
            %save the thing after the "|" but before the ".nii.gz" into a
            %variable, "region_strr"
            try
                meann=curly(curly(textscan(temp{13},'%s'),1),3); %grab the mean from the text file
                sdd=curly(curly(textscan(temp{14},'%s'),1),3); %grab the standard deviation from the text file
            catch
                meann=NaN;
                sdd=NaN;
                if ~contains(temp{3},' 0')
                    warning('grabbing mean and sd failed, but the third line doesn''t seem to indicate that voxel counts are 0')
                    temp{3}
                    i
                    j
                    k
                end
            end
            aggregate{i}{j}{k}{1}=region_strr;
            aggregate{i}{j}{k}{2}=meann;
            aggregate{i}{j}{k}{3}=sdd;
        end
    end
end
toc

% the form of our variable is: aggregate{subject}{metric}{region}{parameter}

% SUBSECTION 4: take the data in the structured variable and put it into
% another variable which will look like an excel sheet. also, QC

% folder_depth_subs_name=8; %CHANGE; This just specifies how deep into your directory tree is a folder that matches your subject names
subns=cellfun(@(x) index_path(x,folder_depth_subs_name),{fibs(fibs_ind).folder},'UniformOutput',0)

for i=1:86
for j=1:7
for k=1:376
%     excell{1,k+1,j}=aggregate{i}{j}{k}{1};
    
    excell{i+1,k+1,j}=aggregate{i}{j}{k}{1}; %create 
    if ~strcmp(excell{1,k+1,j},aggregate{i}{j}{k}{1}) %create 
        warning('your metadata doesn''t match the field in which it''s being entered');
        'aggregate'
        aggregate{i}{j}{k}{1}
        'sheet so far'
        excell{1,k+1,j}
    end
    excell{i+1,k+1,j}=aggregate{i}{j}{k}{2}; %create 
    
    
end
end
end

%give sub names
for i=1:86
for j=1:7
for k=1%:376
%     excell{1,k+1,j}=aggregate{i}{j}{k}{1};
excell{i+1,1,j}=subns{i};
    
    
end
end
end

% QC
checkk=0;
for i=1:86
    for j=1:7
        for k=1:length(region_files)
            if isnan(aggregate{i}{j}{k}{2})
                checkk=checkk+1;
            end
        end
    end
end
% the value of "checkk" will now tell you how many files weren't read
% properly and had their mean/sd set to NaN



% SUBSECTION 4: write to excel sheet
xlwrite_directory='/Users/andrew/bin/bin2/20130227_xlwrite/20130227_xlwrite/'; %CHANGE
addpath(xlwrite_directory)
javs=dir(fullfile(xlwrite_directory,'poi_library/*.jar'));
cellnames=arrayfun(fnify,javs,'UniformOutput',0);
javaaddpath(cellnames)

results_folderr='<Folder>/final_run/feb_results'; %CHANGE
for j=1:7
doc_fn=fullfile(results_folderr,[mets_str{j} '.xlsx']);
xlwrite(doc_fn,excell(1:end,1:end,j))
end




%% SECTION V: Tractography Sharing

% I think connectome_match_string could actually just be defined as
% [output_dir '*/results.txt.pd_n_a.count.pass.connectogram.txt']
connectome_match_string='<Folder>/final_run/feb_dsi/*/results.txt.pd_n_a.count.pass.connectogram.txt';
[iso_matrix,ress]=org_and_clean_cg(connectome_match_string); %CHANGE
connectome_output_folder=fullfile(results_folderr,'connectomes/');

%because of how I did my tractography, DSI didn't know what my region names
%were. So I have to replace those now.
%Use function to change region numbers into region strings
for i=1:86 %this is my number of subjects
    iso_matrix{i}(3:end,2)=replace_number_with_region(label_file,iso_matrix{i}(3:end,2));
    iso_matrix{i}(2,3:end)=iso_matrix{i}(3:end,2);
end

% load into excel
for i1=1:86
    substr=index_path(ress(i1).folder,7);
    excel_doc_fn=fullfile(connectome_output_folder,[substr '.xlsx']);
    xlwrite(excel_doc_fn,iso_matrix{i1});
end 


%reorder the subjects into distinct cohorts for sharing
% you can check which index belongs to each subject like:
%  index4check=58;
%  disp(iso_matrix2{index4check}{1,1})

%these are just indices for each cohort.
nsinds=1:58; %CHANGE
vapinds=65:71; %CHANGE
pdinds=[59:64,72:86]; %CHANGE

% %lets rearrange our "matrix" just to be consistent with how it was shared before
iso_matrix2(1:length(nsinds))=iso_matrix(nsinds);
iso_matrix2(length(nsinds)+(1:length(pdinds)))=iso_matrix(pdinds);
iso_matrix2(length(nsinds)+length(pdinds)+(1:length(vapinds)))=iso_matrix(vapinds);

% QC
bar(cellfun(@(x) sum([x{3:end,1}]),iso_matrix2))
summs=cellfun(@(x) sum([x{3:end,1}]),iso_matrix2);

bar(cellfun(@(x) sum([x{3:end,1}]==0),iso_matrix2))
figure;
bar(summs)
yyaxis right;ab=bar(cellfun(@(x) sum([x{3:end,1}]==0),iso_matrix2));yyaxis left;aa=bar(summs); %1
figure;
yyaxis right;ac=bar(cellfun(@(x) sum([x{3:end,1}]==1),iso_matrix2));yyaxis left;aa=bar(summs); %2
% 1, above, will make a histogram of regions which had no voxels in the
% individual's atlas. The x axis indexes subjects

% 2, above, will make a histogram of regions which had no connections to
% any other region. The x axis indexes subjects


% %% share mats with barbara
save_path=fullfile(results_folderr,'barbshare');
namess=cellfun(@(x) [save_path filesep x{1,1} '.mat'],iso_matrix2,'UniformOutput',0); %don't think these were all meant to be executed
save_cells(iso_matrix2,namess);

function save_cells(celll,names)
for i=1:length(celll)
    matrix=celll{i}(3:end,3:end);
    save(names{i},'matrix')
end

function cell_element_f=replace_number_with_region(label_file,cell_element)
table1=get_table_from_label_file(label_file);

for j1=1:length(cell_element)
region_number_cg{j1}=regexp(cell_element{j1},'region_([0-9]+)','tokens');
suggested_beginning=j1;
% if suggested_beginning<1 || suggested_beginning>length(table1) || ~isint(suggested_beginning); suggested_beginning=1;end %lol
for i1=[suggested_beginning:length(table1),1:suggested_beginning]
    if strcmp(table1{i1,1},region_number_cg{j1}{1}{1})
        cell_element_f{j1}=table1{i1,2};
        break
    end
end
end



function table=get_table_from_label_file(label_file)
i3=1;
fid=fopen(label_file,'r');
while(~feof(fid))
    s=fgetl(fid);
    ind=strfind(s,'|');
    table{i3,1}=s(1:ind-1);% region index
    table{i3,2}=s(ind+1:end);% region name
    i3=i3+1;
end
fclose(fid);
end
end