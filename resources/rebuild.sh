#! /bin/bash

# simple prompt
prompt_yes_no() {
  while true ; do
    printf "$* [Y/n] "
    read answer
    if [ -z "$answer" ] ; then
      return 0
    fi
    case $answer in
      [Yy]|[Yy][Ee][Ss])
        return 0
        ;;
      [Nn]|[Nn][Oo])
        return 1
        ;;
      *)
        echo "Please answer yes or no"
        ;;
    esac
 done
}

# Reading options from rebuild.config
FILENAME=rebuild.config
while read option
do
    export $option
done < $FILENAME

# Start our rebuilding
clear

cat <<EOF

*** IMPORTANT ***

The following values were read from rebuild.config in your resources directory.
Please make sure they are correct before proceeding:

  DB_NAME = $DB_NAME
  DB_USER = $DB_USER
  DB_PASS = $DB_PASS
  DRUPAL_ROOT = $DRUPAL_ROOT

EOF

if ! prompt_yes_no "Are sure these values are correct?" ; then
    exit 1
fi

cat <<EOF

The following operations will be done:

 1. Delete $DRUPAL_ROOT
 2. Rebuild the Drupal directory in $DRUPAL_ROOT
 3. Optionally re-install the skeleton install profile in $DRUPAL_ROOT
 4. Optionally create symlinks from your git repo in $D7_GIT_REPO
    to the new site directory in $DRUPAL_ROOT
 5. Run any necessary Drupal database updates.
 6. Re-sync configuration from data store to active store.

If you have not already run "git pull" to fetch the latest code, you may want to stop this and do that now.

EOF

if ! prompt_yes_no "Are you sure you want to proceed?" ; then
    exit 1
fi

echo 'Rebuilding the site...'
echo 'Removing '$DRUPAL_ROOT' directory...'
chmod a+w $DRUPAL_ROOT"/sites/default"
chmod a+w $DRUPAL_ROOT"/sites/default/files"
mv $DRUPAL_ROOT /tmp/drupal-rebuild-backup
rm -rf $DRUPAL_ROOT
echo 'Executing drush make'
drush make --prepare-install --force-complete --working-copy ../skeleton.build $DRUPAL_ROOT -y
echo 'Finished executing drush make'
cp -r /tmp/drupal-rebuild-backup/sites/default/* $DRUPAL_ROOT"/sites/default"
cd $DRUPAL_ROOT
if prompt_yes_no "Do you want to re-install the database?" ; then
    echo 'Re-installing site database'
    drush si skeleton --site-name="skeleton" --db-url="mysql://root:root@localhost/$D7_DATABASE" -y
    echo 'Done re-installing site database'
fi

# Symlinks

cat <<EOF

Would you like to have symlinks set up? The script will create symlinks as
follows:
  ln -s $D7_GIT_REPO/modules/custom $DRUPAL_ROOT/profiles/skeleton/modules/custom
  ln -s $D7_GIT_REPO/themes/skeleton $DRUPAL_ROOT/profiles/skeleton/themes/skeletontheme

EOF

if ! prompt_yes_no 'Create symlinks?' ; then
    exit 1
fi

echo 'Creating symlinks'
cd $DRUPAL_ROOT
rm -rf profiles/skeleton/modules/custom
rm -rf profiles/skeleton/themes/skeletontheme
ln -s $D7_GIT_REPO"/modules/custom" $DRUPAL_ROOT"/profiles/skeleton/modules/custom"
ln -s $D7_GIT_REPO"/themes/skeleton" $DRUPAL_ROOT"/profiles/skeleton/themes/skeletontheme"
echo 'Done making symlinks.'

echo 'Running any necessary Drupal database updates'
drush updb
echo 'Done.'

echo 'Syncing configuration from data store to active store.'
drush config-sync
echo 'Done.'

echo 'Rebuild completed.'
