#!/bin/sh

# Compile FileZilla for Windows on Ubuntu

# Based on (with modifications from):
# https://svn.filezilla-project.org/filezilla/FileZilla3/
# https://wiki.filezilla-project.org/Cross_Compiling_FileZilla_3_for_Windows_under_Ubuntu_or_Debian_GNU/Linux

set -e

rm -rf ~/prefix
rm -rf ~/src

# These must be run as root
dpkg --add-architecture i386
apt update
apt install -y automake autoconf libtool make gettext lzip
apt install -y mingw-w64 pkg-config wx-common wine wine64 wine32 wine-binfmt subversion git

# Don't install packages, e.g. libfilezilla-dev for cross-compiling!

# Everything else can be run as non-root, if desired.
mkdir ~/prefix
mkdir ~/src
export PATH="$HOME/prefix/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/prefix/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$HOME/prefix/lib/pkgconfig:$PKG_CONFIG_PATH"
export TARGET_HOST=x86_64-w64-mingw32

wine reg add HKCU\\Environment /f /v PATH /d "`x86_64-w64-mingw32-g++ -print-search-dirs | grep ^libraries | sed 's/^libraries: =//' | sed 's/:/;z:/g' | sed 's/^\\//z:\\\\\\\\/' | sed 's/\\//\\\\/g'`"

# GMP
cd ~/src
wget https://gmplib.org/download/gmp/gmp-6.2.1.tar.lz
tar xf gmp-6.2.1.tar.lz
cd gmp-6.2.1
CC_FOR_BUILD=gcc ./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --disable-static --enable-shared --enable-fat
# This fails to build on Debian 11 for me, but it works on Ubuntu
make
make install

# Nettle
cd ~/src
wget https://ftp.gnu.org/gnu/nettle/nettle-3.7.3.tar.gz
tar xf nettle-3.7.3.tar.gz
cd nettle-3.7.3
./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --enable-fat LDFLAGS="-L$HOME/prefix/lib" CPPFLAGS="-I$HOME/prefix/include"
make
make install

# GnuTLS
cd ~/src
wget https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-3.7.8.tar.xz
tar xvf gnutls-3.7.8.tar.xz
cd gnutls-3.7.8
./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --without-p11-kit --with-included-libtasn1 --with-included-unistring --enable-local-libopts --disable-srp-authentication --disable-dtls-srtp-support --disable-heartbeat-support --disable-psk-authentication --disable-anon-authentication --disable-openssl-compatibility --without-tpm --without-zlib --without-brotli --without-zstd --without-idn --enable-threads=windows --disable-cxx LDFLAGS="-L$HOME/prefix/lib" CPPFLAGS="-I$HOME/prefix/include"

# Could fail at some point, but if we get past lib, that's all we need, we're okay
(make && make install) || (make || (cd lib && make install))

# SQLite
cd ~/src
#wget https://sqlite.org/2018/sqlite-autoconf-32600-00.tar.gz # 
#wget https://www.sqlite.com/matrix/2022/sqlite-autoconf-3390400.tar.gz # correct link, but server is down
wget https://github.com/elimuhubconsultant-co-ke/armbian_build/blob/master/sqlite-autoconf-3390300.tar.gz?raw=true
tar xvzf sqlite-autoconf-3390300.tar.gz?raw=true
cd sqlite-autoconf-3390300
./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --disable-dynamic-extensions
make
make install

# NSIS
cd ~/src
wget https://prdownloads.sourceforge.net/nsis/nsis-3.04-setup.exe
wine nsis-3.04-setup.exe /S

[ -f "$HOME/.wine/drive_c/Program Files/NSIS/makensis.exe" ] && echo "Success!"

# wxWidgets
cd ~/src
git clone --branch WX_3_0_BRANCH --single-branch https://github.com/wxWidgets/wxWidgets.git wx3
cd wx3
wget https://filezilla-project.org/nightlies/2023-01-17/patches/wx3/cross_compiling.patch
git apply cross_compiling.patch
./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --enable-gui --enable-printfposparam
make
make install
cp $HOME/prefix/lib/wx*.dll $HOME/prefix/bin

# libfilezilla
cd ~/src
#svn co https://svn.filezilla-project.org/svn/libfilezilla/tags/0.33.0 lfz
svn co https://svn.filezilla-project.org/svn/libfilezilla/trunk lfz
cd lfz
autoreconf -i
./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static
make
make install

# FileZilla
cd ~/src
#svn co https://svn.filezilla-project.org/svn/FileZilla3/tags/3.56.0/ fz
svn co https://svn.filezilla-project.org/svn/FileZilla3/trunk fz
cd fz

## Apply the patch itself.
wget https://raw.githubusercontent.com/InterLinked1/fastfilezilla/master/anytimeouts.diff
svn patch anytimeouts.diff

autoreconf -i
# https://forum.filezilla-project.org/viewtopic.php?style=246&t=42578
export PKG_CONFIG_PATH="$HOME/prefix/lib/pkgconfig/"
./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --with-pugixml=builtin
# NOTE: If you make changes in src, run make clean first, not just make!
make
# strip debug symbols
$TARGET_HOST-strip src/interface/.libs/filezilla.exe
$TARGET_HOST-strip src/putty/.libs/fzsftp.exe
$TARGET_HOST-strip src/putty/.libs/fzputtygen.exe
$TARGET_HOST-strip src/fzshellext/64/.libs/libfzshellext-0.dll
$TARGET_HOST-strip src/fzshellext/32/.libs/libfzshellext-0.dll
$TARGET_HOST-strip data/dlls/*.dll
cd data

# This is slightly modified from the original command on the website
# instead of apt install nsis, use wine:
wine "$HOME/.wine/drive_c/Program Files (x86)/NSIS/makensis.exe" install.nsi

# Voila, there's now FileZilla_3_setup.exe in the current directory.
printf "Cross-compilation of FileZilla has finished."
ls -la FileZilla_3_setup.exe
