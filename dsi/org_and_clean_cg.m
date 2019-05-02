function [iso_matrix,ress]=org_and_clean_cg(fn_patternn)

%% connectogram masterscript
% I NEED TO FIND AND LIST ALL OF MY ASSUMPTIONS IN THIS SCRIPT! 
% especially concerning use of different atlases
fnify=@(x) [x.folder filesep x.name];
%load_connectograms

% WHAT IF I LOADED CONNECTOGRAMS BY 'SPM_SELECT'? 
% that would be pretty user-friendly

[matrixx,ress]=load_connectograms2(fn_patternn);

%make a template matrix to prep for connecto cleaning
template=make_template(matrixx);

%clean connectograms script
% okay so this bit is going to assume that you have generated connectomes
% all using the same atlas. It will pick out one of the atlases with the
% largest dimensions, and use it as a template.

iso_matrix=reblank(matrixx,template);

%I could load connectograms straight into Excel, but there would still be
%inconsistent dimensions. This would be okay if the labeling in excel was
%reaaaaally smart (i.e. it was able to automatically compare regions
%identified by their row AND column strings).
% 
% addpath('/Users/andrew/bin/bin2/20130227_xlwrite/20130227_xlwrite/')
% javs=dir('/Users/andrew/bin/bin2/20130227_xlwrite/20130227_xlwrite/poi_library/*.jar');
% cellnames=arrayfun(fnify,javs,'UniformOutput',0);
% javaaddpath(cellnames)
% 
% 
% % load into excel
% for i1=1:length(iso_matrix)
%     xlwrite(excel_doc_fn,iso_matrix{i1},i1);
% end




end

%BEGIN FUNCTIONS
%---------------
function template1=make_template(matrix)
for i=1:length(matrix)
    sizes(i,:)=size(matrix{i});
end
[~,index]=max(sizes(:,1));
template1=matrix{index};
end

function iso_matrix=reblank(matrix,template1)
for i=1:length(matrix) % each matrix
    numBlanks=0;
    %consider using "while" below
    if any(size(matrix{i})~= size(template1))%dimensions are wrong % MAKE THIS MORE GENERAL
        for j=3:length(template1)% each row in each subjects own string array
            if ~strcmp(matrix{i}{j,2},template1{j,2})% strings arent equivalent 
                numBlanks=numBlanks+1;
                %spare{i}{numBlanks}=matrix{i};
                
                matrix{i}(j+1:end+1,j+1:end+1)=matrix{i}(j:end,j:end);
                matrix{i}(1:j,j+1:end+1)=matrix{i}(1:j,j:end); 
                matrix{i}(j+1:end+1,1:j)=matrix{i}(j:end,1:j); 
                
                matrix{i}(j,:)={0};
                matrix{i}(:,j)={0};
            end
        end
        matrix{i}(end-(numBlanks-1):end,:)=[];
        matrix{i}(:,end-(numBlanks-1):end)=[];
    end
end
iso_matrix=matrix;
end

function varargout=load_connectograms2(fn_pattern)
% If given, varargout is the results structure array, and the user can make
% sure the index of the filenames matches the index of the matrix cell they
% want to look at 
% nargoutchk(1,2)
%results=dir('V:\taylor_j\leo\dr_cooper\PD_MRIs2\PD_MRIs\VaP*\dke\VaP*_results.txt.atlas_VaP*.count.end.connectogram.txt');
results=dir(fn_pattern);
%sanitize/inform
if isempty(results)
    error('no files were found');
end
%sanitize input 'r whatever
problem_index=[];
%problem_index2=[];
for j=1:length(results)
    if results(j).isdir==1
        problem_index=[problem_index j];
    end
%     if ~contains(results(j).name,'connectogram')
%         problem_index2=[problem_index2 j];
%     end
end
% problem_indices=union(problem_index,problem_index2);
% results(problem_indices)=[];
results(problem_index)=[];
for i=1:length(results)
    con_matrix{i}=delimread([results(i).folder filesep results(i).name],{' ','\t'},'mixed');
    matrix{i}=con_matrix{i}.mixed;
    
    %assuming file structure:
    matrix{i}{1}=choose_output(@() fileparts(results(i).folder),2);
    
end

%assuming file structure:



varargout{1}=matrix;
if nargout==2
    varargout{2}=results;
end
end