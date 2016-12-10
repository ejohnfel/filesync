# filesync
Given two source folders of files, index the files and determine which copies are duplicates or unique and then either synchronize the files or execute some other operation on the source or destination folder tree (i.e. delete duplicates).

The key feature of this tool is that the file search is not limited strictly to the pathes in either folder structure. The purpose is to synchronize (or cull) the files, not the folder structure.

During a synchronization operation, files that do not exist in the destination will be copied to the same path that they exist in source folder structure, minus the root path of each file (i.e. the files will be grafted into the destinations root path).

The purpose is to synchronize or delete files by content, not folder location.
