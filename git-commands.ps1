# Configure Git user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Initialize a new Git repository in the current directory
git init

# Check the status of your Git repository
git status

# Add all files to the staging area for the next commit
git add .

# Commit changes with a descriptive message
git commit -m "My first commit, welcome Seattle"

# Undo the last commit while keeping changes in the working directory
git reset HEAD~1

# Add and Commit changes with a descriptive message
git commit -a -m "My second commit, welcome Seattle"

# Show the commit history
git log

# Show a visual representation of the commit history (ASCII art)
git log --graph --oneline --all

# Pull changes from a remote repository
git pull

# Push changes to a remote repository
git push

# Show differences between files or branches
git diff

# Create a new branch and switch to it 
git checkout -b breakfast

# Create a new branch
git branch <branch_name>

# Switch to an existing branch
git checkout <branch_name>

# Create a new branch and switch to it in a single command
git checkout -b <new_branch_name>

# Merge changes from one branch into another
git merge <source_branch_name>

# List all branches in the repository
git branch

# Amend the last commit with new changes
git commit --amend

# Clone a remote repository to your local machine
git clone https://github.com/promicroNL/gydbuc


<#

ADVANCED

#>

# Rebase changes from one branch onto another interactively
git rebase -i <target_branch>

# Cherry-pick a specific commit from one branch to another
git cherry-pick <commit_hash>

# Create a stash to save changes temporarily
git stash save "Your stash message here"

# Apply changes from a stash to the current branch
git stash apply

# Show a graphical representation of branches and commits
git log --graph --oneline --all --decorate

git log --graph --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(dim white)- %s%C(reset)' –all

# changing the default branch
git config --global init.defaultBranch main

# git autocorrect
git config --global help.autocorrect 20  # correct after 2 seconds
git config --global help.autocorrect 0   # auto correct off

# View detailed information about a specific commit
git show a56273c

# Show the difference between a local branch and a remote branch
git diff master lunch

# Rename a branch
git branch -m lunch tonie

# Squash multiple commits into a single commit interactively
git rebase -i HEAD~<number_of_commits>

# List remote repositories and their URLs
git remote -v

# Set up tracking for a remote branch
git branch --set-upstream-to=<remote>/<remote_branch>

# Fetch changes from a remote repository without merging
git fetch <remote_name>

# Create and apply a patch file for changes
git format-patch -1 <commit_hash>

# Apply a patch file to a branch
git apply <patch_file>

# Show the blame (annotated) view of a file
git blame .\git-commands.ps1
