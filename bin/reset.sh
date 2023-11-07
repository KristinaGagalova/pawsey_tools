#!/usr/bin/env bash

# Add the -e option to exit on error
set -e

# Check for the correct number of arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 username"
  exit 1
fi

username="$1"
group="/scratch/y95/"

# Check if user directory name exists
if [ ! -d "${group}/${username}" ]; then
  echo "Error: The user name ${username} does't exist. Please check if input is correct."
  exit 1
fi

# Check if there are running jobs for your username
#if squeue -u "$username" | grep -q R; then
#  echo "You have running jobs on SLURM. Stopping the script. Please re-run when you don't have active runs."
#  exit 1
#else
#  echo "No running jobs found. Proceeding with the script."
  # Add your script logic here
#fi

# move to directory to recreate
cd "${group}/${username}/"
echo `pwd`

list_files_in_current_directory() {
  echo "These are the files in the current directory:"
  
  # Iterate through all files in the current directory
  for file in *; do
    if [ -f "$file" ]; then
      echo "$file"
    fi
  done
}

echo "The following files won't be touched by this process."

list_files_in_current_directory

echo "Starting to re-generate the folders in ${group}/${username}/"

# Iterate through directories in the user directory
for dir in ./*; do

  if [ -d "$dir" ]; then
    
    echo $dir
    # Create a temporary directory name by adding "TMP" to the original name
    tmp_dir="${dir}TMP"
    
    # Copy the directory to the temporary name
    cp -r "$dir" "$tmp_dir"
    
    # Remove the original directory
    rm -r "$dir"
    
    # Move the temporary directory back to the original name
    mv "$tmp_dir" "$dir"
    
    echo "Renamed '$dir' to '$tmp_dir' and then back to '$dir'"
  fi

done

echo "User '${username}' directories have been re-created."
