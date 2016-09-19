function p = FolderExceptionList
%FOLDEREXCEPTIONLIST Exceptions to the search path folders from the dependency list.
%   FOLDEREXCEPTIONLIST returns a string that can be used as input to RMPATH

p = [...
%%% BEGIN ENTRIES %%%
     genpath('M:\amtoolbox\thirdparty\sfs\doc'), ...
     genpath('M:\amtoolbox\thirdparty\sfs\SFS_octave'), ...
     genpath('M:\amtoolbox\thirdparty\src'), ...
     genpath('M:\SpeechSP_Tools\.git'), ...
%%% END ENTRIES %%%
     ...
];

