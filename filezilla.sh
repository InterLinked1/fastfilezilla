#!/bin/sh

# Compile FileZilla for Windows on Ubuntu 22 or Debian 12 (11 not supported)

START_OVER=1 # Completely start a fresh build from scratch
INSTALL_PACKAGES=1 # Automatically install required packages. Only needed the first time.
NEED_BOOST_REGEX=1 # needed for 3.65.0 and newer but not for 3.62.2

# Which patches to apply:
PATCH_ANY_TIMEOUTS=1
PATCH_SHORT_TAB_NAMES=1

# Last tested with FileZilla 3.67.1, Debian 12
# Previously tested with FileZilla 3.65.0, Debian 12
# Originally tested with FileZilla 3.62.2, Ubuntu 22

# Based on (with modifications from):
# https://svn.filezilla-project.org/filezilla/FileZilla3/
# https://wiki.filezilla-project.org/Cross_Compiling_FileZilla_3_for_Windows_under_Ubuntu_or_Debian_GNU/Linux

set -e

if [ "$START_OVER" = "1" ]; then
	rm -rf ~/prefix
	rm -rf ~/src
fi

# These must be run as root
dpkg --add-architecture i386

if [ "$INSTALL_PACKAGES" = "1" ]; then
	apt update
	apt install -y automake autoconf libtool make gettext lzip bzip2
	apt install -y mingw-w64 pkg-config wx-common wine wine64 wine32 wine-binfmt subversion git g++
fi

# Don't install packages, e.g. libfilezilla-dev for cross-compiling!

# Everything else can be run as non-root, if desired.

if [ "$START_OVER" = "1" ]; then
	mkdir ~/prefix
	mkdir ~/src
fi

export PATH="$HOME/prefix/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/prefix/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$HOME/prefix/lib/pkgconfig:$PKG_CONFIG_PATH"
export TARGET_HOST=x86_64-w64-mingw32

# Explicitly target Windows 7 to avoid using GetSystemTimePreciseAsFileTime, which is Windows 8+ only.
# See also: --with-default-win32-winnt=0x0601
export CPPFLAGS="-D_WIN32_WINNT=0x0601"

wine reg add HKCU\\Environment /f /v PATH /d "`x86_64-w64-mingw32-g++ -print-search-dirs | grep ^libraries | sed 's/^libraries: =//' | sed 's/:/;z:/g' | sed 's/^\\//z:\\\\\\\\/' | sed 's/\\//\\\\/g'`"

if [ "$NEED_BOOST_REGEX" = "1" ]; then
	# Boost Regex 1.76+
	cd ~/src
	wget https://boostorg.jfrog.io/artifactory/main/release/1.76.0/source/boost_1_76_0.tar.bz2
	tar --bzip2 -xf boost_1_76_0.tar.bz2
	cd boost_1_76_0
	# The following two steps *might* be optional? Didn't work the first time, but worked eventually...
	#./bootstrap.sh --prefix="$HOME/prefix"
	#./b2 headers

	# Determine the include path from the first line of:
	x86_64-w64-mingw32-g++ -std=c++17 -c -std=c++17 -E -x c++ -v /dev/null

	cp -r ~/src/boost_1_76_0/boost/ /usr/lib/gcc/x86_64-w64-mingw32/12-win32/include/c++/
fi

# GMP
cd ~/src
if [ ! -d gmp-6.2.1 ]; then
	wget https://gmplib.org/download/gmp/gmp-6.2.1.tar.lz
	tar xf gmp-6.2.1.tar.lz
fi
cd gmp-6.2.1
CC_FOR_BUILD=gcc ./configure --with-default-win32-winnt=0x0601 --host=$TARGET_HOST --prefix="$HOME/prefix" --disable-static --enable-shared --enable-fat
# This fails to build on Debian 11 for me, but it works on Ubuntu
make
make install

# Nettle
cd ~/src
wget https://ftp.gnu.org/gnu/nettle/nettle-3.7.3.tar.gz
tar xf nettle-3.7.3.tar.gz
cd nettle-3.7.3
./configure --with-default-win32-winnt=0x0601 --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --enable-fat LDFLAGS="-L$HOME/prefix/lib" CPPFLAGS="-I$HOME/prefix/include -D_WIN32_WINNT=0x0601"
make
make install

# GnuTLS
cd ~/src
wget https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-3.7.8.tar.xz
tar xvf gnutls-3.7.8.tar.xz
cd gnutls-3.7.8
./configure --with-default-win32-winnt=0x0601 --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --without-p11-kit --with-included-libtasn1 --with-included-unistring --enable-local-libopts --disable-srp-authentication --disable-dtls-srtp-support --disable-heartbeat-support --disable-psk-authentication --disable-anon-authentication --disable-openssl-compatibility --without-tpm --without-zlib --without-brotli --without-zstd --without-idn --enable-threads=windows --disable-cxx LDFLAGS="-L$HOME/prefix/lib" CPPFLAGS="-I$HOME/prefix/include -D_WIN32_WINNT=0x0601"

# Could fail at some point, but if we get past lib, that's all we need, we're okay
(make && make install) || (make || (cd lib && make install))

# SQLite
cd ~/src
#wget https://sqlite.org/2018/sqlite-autoconf-32600-00.tar.gz # 
#wget https://www.sqlite.com/matrix/2022/sqlite-autoconf-3390400.tar.gz # correct link, but server is down
wget https://github.com/elimuhubconsultant-co-ke/armbian_build/raw/master/sqlite-autoconf-3390300.tar.gz
tar xvzf sqlite-autoconf-3390300.tar.gz
cd sqlite-autoconf-3390300
./configure --with-default-win32-winnt=0x0601 --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --disable-dynamic-extensions
make
make install

# NSIS
cd ~/src
wget https://prdownloads.sourceforge.net/nsis/nsis-3.04-setup.exe
wine nsis-3.04-setup.exe /S

[ -f "$HOME/.wine/drive_c/Program Files/NSIS/makensis.exe" ] && echo "Success!"

# wxWidgets
cd ~/src
git clone --recurse-submodules --branch 3.2 --single-branch https://github.com/wxWidgets/wxWidgets.git wx3
cd wx3
wget https://filezilla-project.org/nightlies/latest/patches/wx3.2/cross_compiling.patch
git apply cross_compiling.patch
./configure --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --enable-unicode --enable-gui --enable-printfposparam
make
make install
# Seems like the cross_compiling patch above doesn't really fix this issue
# see: https://forum.filezilla-project.org/viewtopic.php?p=192640#p192577
find . -type f -name '*-x86_64-w64-mingw32.dll.a' | sed -e 'p;s/-x86_64-w64-mingw32.dll.a/.dll.a/' | xargs -n2 mv
cp $HOME/prefix/lib/wx*.dll $HOME/prefix/bin || true

# libfilezilla
export CXXFLAGS=-std=c++17
cd ~/src
#svn co https://svn.filezilla-project.org/svn/libfilezilla/tags/0.33.0 lfz
svn co https://svn.filezilla-project.org/svn/libfilezilla/trunk lfz
cd lfz
autoreconf -i
./configure --with-default-win32-winnt=0x0601 --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static
make
make install

# FileZilla
cd ~/src
#svn co https://svn.filezilla-project.org/svn/FileZilla3/tags/3.56.0/ fz
svn co https://svn.filezilla-project.org/svn/FileZilla3/trunk fz
cd fz

## Apply any custom patches:
if [ "$PATCH_ANY_TIMEOUTS" = "1" ]; then
	wget https://raw.githubusercontent.com/InterLinked1/fastfilezilla/master/anytimeouts.diff
	svn patch anytimeouts.diff
fi
if [ "$PATCH_SHORT_TAB_NAMES" = "1" ]; then
	wget https://raw.githubusercontent.com/InterLinked1/fastfilezilla/master/short_tab_names.diff
	svn patch short_tab_names.diff
fi

#autoupdate
autoreconf -i
# https://forum.filezilla-project.org/viewtopic.php?style=246&t=42578
export PKG_CONFIG_PATH="$HOME/prefix/lib/pkgconfig/"

# If configure fails, for debugging, these SHOULD succeed. If not, boost headers aren't installed.
# echo "#include <boost/regex.hpp>" > conftest.cpp
# x86_64-w64-mingw32-g++ -std=c++17 -c -std=c++17 -Wall -g conftest.cpp

# Do not run make clean here. There is no clean target.

# Disable updates, since we're compiling a custom build, so those aren't relevant. We'll need to rebuild from source again, on our terms.
# --disable-manualupdatecheck includes --disable-autoupdatecheck
./configure --with-default-win32-winnt=0x0601 --host=$TARGET_HOST --prefix="$HOME/prefix" --enable-shared --disable-static --with-pugixml=builtin --disable-manualupdatecheck
# NOTE: If you make changes in src, run make clean first, not just make!
make
# strip debug symbols
$TARGET_HOST-strip src/interface/.libs/filezilla.exe
$TARGET_HOST-strip src/putty/.libs/fzsftp.exe
$TARGET_HOST-strip src/putty/.libs/fzputtygen.exe
$TARGET_HOST-strip src/fzshellext/64/.libs/libfzshellext-0.dll
$TARGET_HOST-strip src/fzshellext/32/.libs/libfzshellext-0.dll
#$TARGET_HOST-strip data/dlls/*.dll
# Seems the folder name got changed?
$TARGET_HOST-strip data/dlls/*.dll || $TARGET_HOST-strip data/dlls_gui/*.dll

# This symbol is incompatible with Windows 7 and must not exist in the result
grep -R "GetSystemTimePreciseAsFileTime"

cd data

# This is slightly modified from the original command on the website
# instead of apt install nsis, use wine:
wine "$HOME/.wine/drive_c/Program Files (x86)/NSIS/makensis.exe" install.nsi

# Voila, there's now FileZilla_3_setup.exe in the current directory.
printf "Cross-compilation of FileZilla has finished.\n"
pwd
ls -la FileZilla_3_setup.exe
