#!/bin/sh

set -e

SOURCE_REPO=$1
SOURCE_BRANCH=$2
DESTINATION_REPO=$3
DESTINATION_BRANCH=$4
USE_LFS=$5

if ! echo $SOURCE_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
    SOURCE_REPO="git@github.com:${SOURCE_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    SOURCE_REPO="https://github.com/${SOURCE_REPO}.git"
  fi
fi

if ! echo $DESTINATION_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
    DESTINATION_REPO="git@github.com:${DESTINATION_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    DESTINATION_REPO="https://github.com/${DESTINATION_REPO}.git"
  fi
fi

echo "SOURCE=$SOURCE_REPO:$SOURCE_BRANCH"
echo "DESTINATION=$DESTINATION_REPO:$DESTINATION_BRANCH"

if [[ -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
  # Clone using source ssh key if provided
  git clone -c core.sshCommand="/usr/bin/ssh -i ~/.ssh/src_rsa" "$SOURCE_REPO" /root/source --origin source && cd /root/source
else
  git clone "$SOURCE_REPO" /root/source --origin source && cd /root/source
fi

git remote add destination "$DESTINATION_REPO"

# Check if the repository required LFS
if [[ "$USE_LFS" == "true" ]]; then
  # Ensure git-lfs is installed and initialized
  if ! command -v git-lfs >/dev/null 2>&1; then
    echo "❌ Git LFS is not installed."
    exit 1
  fi
  git lfs install
  git lfs pull source
else
  echo "Skipping LFS pull as USE_LFS is set to false."
fi

# Pull all branches references down locally so subsequent commands can see them
git fetch source '+refs/heads/*:refs/heads/*' --update-head-ok

# Print out all branches
git --no-pager branch -a -vv

if [[ -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
  # Push using destination ssh key if provided
  git config --local core.sshCommand "/usr/bin/ssh -i ~/.ssh/dst_rsa"
fi

if [[ "$USE_LFS" == "true" ]]; then
  GIT_TRACE=1 GIT_CURL_VERBOSE=1 git lfs push destination "$SOURCE_BRANCH"
else
  echo "Skipping LFS push as USE_LFS is set to false."
fi

git push destination "${SOURCE_BRANCH}:${DESTINATION_BRANCH}" -f
