#!/bin/bash

set -e

REMOTE=$1
PEM=$2

CMAKE_VERSION="3.18.4"
CMAKE_HASH="149e0cee002e59e0bb84543cf3cb099f108c08390392605e944daeb6594cbc29"

if [[ $REMOTE = "" || $PEM = "" ]]; then
	echo "Usage: ./ssh-build.sh HOST-IP PEM-FILE"
	exit 1
fi

append() {
	echo $1 >> tmp_script.sh
}

CMAKE_DIR="cmake-$CMAKE_VERSION-Linux-x86_64"
CMAKE_FILE="$CMAKE_DIR.tar.gz"

rm -rf ../app/src/main/jniLibs/
rm -rf ../app/wrap/

echo "==> Build on $1 using $2 as the key..."

echo "" > tmp_script.sh
append "#!/bin/bash"
append "set -e"
append "sudo apt -y update"
append "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq"
append "sudo apt -y install build-essential gcc-multilib htop python unzip pkg-config p7zip-full"
append "sudo umount /mnt || true"
append "sudo mount -t tmpfs -o size=64G tmpfs /mnt"
append "wget https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/$CMAKE_FILE"
append "echo '$CMAKE_HASH $CMAKE_FILE' | sha256sum -c - || exit 1"
append "tar xvf $CMAKE_FILE"
append "cd /home/ubuntu/"
append "export PATH=/home/ubuntu/$CMAKE_DIR/bin/:\$PATH"
append "cd /mnt"
append "git clone https://github.com/xyzz/openmw-android.git"
append "cd openmw-android/buildscripts"
append "git checkout $(git rev-parse HEAD)"
append "time ./full-build.sh"
append "./package-symbols.sh"

echo "==> Uploading the script"

scp -i $PEM tmp_script.sh ubuntu@$REMOTE:/home/ubuntu/

echo "==> Running the script"
ssh -i $PEM -o ServerAliveInterval=60 ubuntu@$REMOTE "bash tmp_script.sh"

echo "==> Retrieving the libraries"
scp -r -i $PEM ubuntu@$REMOTE:/mnt/openmw-android/app/src/main/jniLibs ../app/src/main/

rm -rf ../app/src/main/assets/libopenmw/
echo "==> Retrieving the resources"
scp -r -i $PEM ubuntu@$REMOTE:/mnt/openmw-android/app/src/main/assets/libopenmw ../app/src/main/assets/

echo "==> Retrieving the symbols"
rm -f symbols.7z
scp -r -i $PEM ubuntu@$REMOTE:/mnt/openmw-android/buildscripts/symbols.7z .

echo "==> Extracting the symbols"
rm -rf symbols
7z x symbols.7z

echo "==> All OK!"
