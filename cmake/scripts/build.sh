srcdir=$(pwd)
builddir="$srcdir/build"

rm -rf $builddir
mkdir $builddir
cmake -B $builddir
cmake --build ./$builddir
