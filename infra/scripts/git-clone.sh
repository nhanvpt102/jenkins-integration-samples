#!/bin/bash

list_repo="gateway ninjamart-customer ninjamart-custom-identityprovider ninjamart-fe ninjamart-jdl-k8s-deployment ninjamart-job ninjamart-order ninjavan-report ninjavan-warehouse"
root_folder=$(pwd)

for repo in $list_repo; do
	echo $repo
	if [[ -d "$root_folder/$repo" ]]; then
		pushd "$root_folder/$repo"
			echo "Go to $root_folder/$repo"
			git pull
		popd
	else
		echo "git clone ssh://git@178.32.238.19:7999/njv/${repo}.git"
		git clone "ssh://git@178.32.238.19:7999/njv/${repo}.git"
	fi
done

repo="jenkins-integration-samples"
if [[ -d "$root_folder/$repo" ]]; then
	pushd "$root_folder/$repo"
		echo "Go to $root_folder/$repo"
		git pull
	popd
else
	echo "git clone git@github.com:nhanvpt102/${repo}.git"
	git clone "git@github.com:nhanvpt102/${repo}.git"
fi
