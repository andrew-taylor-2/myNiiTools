function [matrix,ress]=org_and_clean_cg(fn_patternn)


%----
% Script Purpose:
%     Connectomes output by DSI Studio can vary in dimension if a region does not have any connections.
%     This script takes a file pattern for a group of connectomes, makes a template "full" connectome,
%     and fills in the blank entries with zeros. This does assume that there is at least one selected
%     connectome that is full-size. Emperically, this is a safe assumption.
%----

fnify=@(x) [x.folder filesep x.name];

%----
% Read text files into workspace
%----

[matrixx,ress]=load_connectograms2(fn_patternn);

%----
% Make a template "full-sized" connectome
%----

template=make_template(matrixx);

%----
% Fill out matrix with zeros
%----

iso_matrix=reblank(matrixx,template);

end

%BEGIN SUBFUNCTIONS
%---------------
function template1=make_template(matrix)
for i=1:length(matrix)
    sizes(i,:)=size(matrix{i});
end
[~,index]=max(sizes(:,1));
template1=matrix{index};
end


function matrix=reblank(matrix,template1)
for i=1:length(matrix) % each matrix
    numBlanks=0;
    if any(size(matrix{i})~= size(template1)) % if dimensions of the current matrix aren't the same size as the template (they'll be smaller)
        for j=3:length(template1)% for each row in each subjects own string array
            if ~strcmp(matrix{i}{j,2},template1{j,2})% if strings arent equivalent

                numBlanks=numBlanks+1;

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

results=dir(fn_pattern);
assert(~isempty(results),'no files were found')


%sanitize input
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

varargout{1}=matrix;
if nargout==2
    varargout{2}=results;
end
end
