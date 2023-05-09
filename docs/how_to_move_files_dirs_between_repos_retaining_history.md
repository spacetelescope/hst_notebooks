# How to copy files and directories from one Git repository to another preserving revision histroy and source material path structure
### Assumptions and other things to bear in mind ahead of time
* I make use of [git-filter-repo](https://github.com/newren/git-filter-repo)
* I borrowed a bit from [Bill Cawtha's](https://blog.billyc.io/how-to-copy-one-or-more-files-from-one-git-repo-to-another-and-keep-the-git-history/) instructions on this.
* These instructions assume the source repository is named \<SOURCE REPO> and the destination repository is named \<DEST REPO>
* These instructions assume that repositories are on the _main_ branch
 
#### In the source repository...
1. Create directory that will contain everything what will be moved
```
  <SOURCE REPO> $ mkdir stuff_to_move
```

2. Use _filter-repo_ to move files and/or directories to the _stuff_to_move_ directory, retaining revision history
```
  <SOURCE REPO> $ git filter-repo --path-rename <file or directory to move>:stuff_to_move/.
```
* **NOTE:** This step only works for a single file or directory at a time so multiple executions of this command need to be done for each file or directory to be moved.    

3. Once everything is moved to _stuff_to_move_, filter out and remove all other files/directories and all unrelated revision history
```
  <SOURCE REPO> $ git filter-repo --path stuff_to_move --refs refs/heads/main --force
```

#### In the destination repository...
4: cd to the destination repository
```
  <SOURCE REPO> $ cd ../<DEST REPO>
```

5: Check out a new branch
```
  <DEST REPO> $ git checkout -b filter-target
```

6: Remote add and fetch the source repository
```
  <DEST REPO> $ git remote add repo-source ../<SOURCE REPO>
  <DEST REPO> $ git fetch repo-source
```

7: Migrate items from \<SOURCE REPO> into \<DEST REPO>
```
    <DEST REPO> $ git branch branch-source remotes/repo-source/main
    <DEST REPO> $ git merge branch-source --allow-unrelated-histories
```

8: Push the _filter-target_ branch to remote _origin_
```
    git push -u origin filter-target
```
...and that's it. The result is the the _stuff_to_move_ directory sitting in the top level of \<DEST REPO> retaining it's pre-migration directory structure. The revision history 
      of all the migrated items has been inserted into \<DEST REPO>'s history. The _filter-target_ branch is stored in remote _origin_ ready for more changes.
