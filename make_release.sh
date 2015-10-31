#!/bin/bash

# CometVisu release creation script
# (c) by Christian Mayer
#
# This script assumes that the GitHub repository already has a branch named "release-<VERSION>"

VERSIONBRANCH="$1"

if [ -z $VERSIONBRANCH ] || [ x"$VERSIONBRANCH" = "x-help" ]; then
  echo "Call script with the new version name as parameter like
  $0 \"1.2.3\" [\"-RC1\"] [-force]"
  echo
  echo The 1st parameter must exist as a branch name in the Git
  echo The 2nd parameter is optional and can be used to add a postfix to the release name
  echo As a last parameter -force can the used to overwrite the build directory when it is already existing
  exit
fi

POSTFIX=""
if [ -n $2 ] && [ ! x"$2" = "x-force" ] ; then
  POSTFIX="$2"
fi

VERSION="$VERSIONBRANCH$POSTFIX"
WORKDIR="/tmp/cvrelease"
RELEASE_BRANCH="release-$VERSIONBRANCH"
RELEASE_DIR="release_$VERSION"
GIT_CMD="git"

FORCE=0
if [ x"$2" = "x-force" ] || [ x"$3" = "x-force" ] ; then
  echo "Using option: Force script even when working directory is already existing!"
  FORCE=1
fi

echo "Creating Release: '$VERSION' out of branch '$RELEASE_BRANCH' in '$RELEASE_DIR'"

# Make sure we start at the location of this script
# NOTE: the script assumes to live at .../CometVisu/_support
cd "$( dirname "${BASH_SOURCE[0]}" )"
SCRIPT_DIR=`pwd`

echo "source dir: '$SCRIPT_DIR'"
echo "option force: $FORCE"

# make sure the temp directory does not exist
WORKDIR_EXISTING=0
if [ -e "$WORKDIR" ]; then
  echo "Error: working directory '$WORKDIR' does already exist! Please delete it!"
  WORKDIR_EXISTING=1
fi

if [ $WORKDIR_EXISTING -eq 1 ]; then
  if [ $FORCE -eq 0 ]; then
    echo "-> Stopping script"
    exit 1
  else
    echo "Deleting working directory now"
    rm -rf $WORKDIR
  fi
fi

mkdir $WORKDIR
cd $WORKDIR

# Get code
$GIT_CMD clone https://github.com/CometVisu/CometVisu.git --branch $RELEASE_BRANCH --single-branch --depth 1

# Set version
echo $VERSION > CometVisu/VERSION
echo $VERSION > CometVisu/src/version
sed -i "s/Version: Git/Version: $VERSION/" CometVisu/src/config/visu_config.xml 
sed -i "s/Version: Git/Version: $VERSION/" CometVisu/src/config/demo/visu_config_demo.xml 
sed -i "s/comet_16x16_000000.png/comet_16x16_ff8000.png/" CometVisu/src/index.html

cd CometVisu

#make
JS_ENGINE=`which node nodejs 2>/dev/null | head -n 1`
if [ x"$JS_ENGINE" = "x" ]; then
  echo Fatal error: no node or nodejs found on the system. Please install!
  exit 1
fi
export NODE_PATH=$SCRIPT_DIR
TIMESTAMP=`date +%Y%m%d-%H%M%S`
STATIC_FILES_PRE=$(cat src/cometvisu.appcache  | sed '0,/T MODIFY!$/{//!b};d')
STATIC_FILES_POST=$(cat src/cometvisu.appcache  | sed '/^NETWORK:$/,/^$/{//!b};d')
PLUGIN_FILES=$(find src | grep plugins | grep -E "structure_plugin.js|\.css" | sed 's%src/%%')
DESIGN_FILES=$(find src | grep designs | grep -E "\.js|\.css|\.ttf" | grep -v "custom.css" | sed 's%src/%%')
mkdir -p ./release
$JS_ENGINE $SCRIPT_DIR/r.js -o build.js
find release -path "*/.svn" -exec rm -rf {} +
echo -e "$STATIC_FILES_PRE\n$DESIGN_FILES\n$PLUGIN_FILES\n\nNETWORK:\n$STATIC_FILES_POST" | \
  sed "s/# Version.*/# Version $VERSION:$TIMESTAMP/"  \
  > release/cometvisu.appcache
rm release/build.txt

chmod -R a+w src/config
chmod -R a+w release/config
# why do I need this?!? I'd expect r.js to create that dir already...
mkdir -p release/config/backup
chmod -R a+w release/config/backup

echo Ready to create...

cd ..
tar -cjp --exclude-vcs  -f CometVisu_$VERSION.tar.bz2 CometVisu

cd $SCRIPT_DIR

echo done...
echo Release package is stored at $WORKDIR/CometVisu_$VERSION.tar.bz2 
echo
echo Next steps:
echo Go to GitHub, releases
echo "-> Draft new Release"
echo "-> Give release the number (like v$VERSION)"
echo "-> Drag and drop the release package file on the relevant field"
