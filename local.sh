rm -rf .release/
mkdir .release
wget -O .release/release.sh https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh
chmod +x .release/release.sh
./.release/release.sh
