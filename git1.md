
# Set the author name for your commits
git config --global user.name "[Your Name]"

# Set the author email for your commits
git config --global user.email "[your.email@example.com]"



# initialize a new repository
git init

# clone an existing repository from Github to local PC
git clone "[url]"

# clone an existing repository, and specify name of target directory on local PC
git clone "url" my-project # will clone the repository to the folder `my-project`.

# show files or directories that were changed (or that still need to be added)
# files that are already in the staging area are green; files that are not
# in the staging area are red.
git status

# add a directory or file to the staging area
git add directory-name-or-file-name
# for example, git add sourcecode.R, or dir-name/sourcecode.R.

# run git status again, to see that the files have "turned green"
git status

# added a wrong file to the staging area, and want it to turn "red" again?
git reset directory-name-or-file-name

# are you happy with what is green in your staging area? Then it's
# time to finalize your save operation by initiating a so-called "commit".
git commit -m "message"
# (give it a clear message, so that you can easily roll back to this version
# of your repository.

# This is effectively the only git commit command I ever use, and why you never really need to run the “git add .”:
git commit -am "message"

# optionally, use git log to see the versioning history
git log

# (1) DOWNLOAD AND MERGE CHANGES

# download and merge any changes from the remote/GitHub
git pull

# alternatively, you can do the same in two steps:
# What fetch does is it grabs all of the new code on remote so you can play around with it locally (rebase, cherry-pick, check out a new branch, etc). Unlike git pull, it doesn’t do anything with your local code; you are fully in control. This is why git pull is risky. “git pull” is one of those things they teach you in school to get you up and running with git with as few commands memorized as possible (I did git pull all the time back in university). In short, git pull does a fetch and then a merge, which gives you less control over how you want the new code to be integrated with yours. Here is how you do a fetch:

git fetch # fetches changes
git merge # merges changes with your local files

# (2) UPLOAD CHANGES

# upload all local branch commits to GitHub
git push

# However, push is actually structured like this:

git push REMOTE_NAME BRANCH_NAME
# By default, Git will push to whatever remote lies at origin. It will also push all local branches that don’t match their counterparts on the remote side, counterparts being determined by a simple name match. Keep these notes in mind for when you’re pushing to non-origin remotes and the much rarer case of your local branch not having the same name as the remote one you’re updating.

# If you want to be specific and push a specific branch to a certain remote, you can use the following:
git push remote_name my_local_branch_name:remote_branch_name

# This tells you exactly what code changes Git is currently aware
git diff FILE_PATH


git branch
Figure out what branches exist (both local and remote)

git branch -av
-a (all)
-v (verbose)
If you’re missing a branch, you either need to convert a remote branch into a local one and/or do a fetch.

Start working on another branch

git checkout BRANCH_NAME

git cherry-pick

git stash