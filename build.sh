#!/usr/bin/env bash

#------------------------------------------------------------------------------------------#
# Standard block for each bashbuild script - these are used for copyright notices, packages
# this standard block ends around line 45
#------------------------------------------------------------------------------------------#

# ensure we're running from our directory and that we haven't been called from somewhere else
cd "$(dirname $0)"
[[ "$(basename $0)" != "build.sh" ]] && echo "$0 must be named build.sh" 1>&2 && exit 9

# As this is the top level script so we force remove any saved envs here before saving new
# ones, this next line can be optionally added/removed as needed.
find . -type f -name '.env-*' -exec rm -f {} \;
# Include and execute unified build library code - this part is critical
[[ -z "$TLD" ]] && export TLD="${PWD}"
# set the local top level directory for this build, as we go down into subdirs and run
# build, TLD will be the top, but XTLD will be the "local" build's TLD.
export XTLD="$( /bin/pwd )"

if  [[ -x "${TLD}/bashbuild/src.build" ]]; then
    is_bashbuild_loaded 2>/dev/null || source ${TLD}/bashbuild/src.build
else
    echo "$PWD/$0 Cannot find $PWD/bashbuild/src.build" 1>&2
    echo "This is required as it contains the shared code for the unified build system scripts." 1>&2
    exit 1
fi

###########################################################################################
# if you're making your own package using the src.build system, you'll want to set
# these variables.  These will help populate the appropriate fields in packages.
###########################################################################################
   SOFTWARE="LisaEm"                    # name of the software (can contain upper case)
     LCNAME="lisaem"                    # lower case name used for the directory
DESCRIPTION="The first fully functional Lisa Emulator™"   # description of the package
        VER="1.2.7"                     # just the version number
  STABILITY="ALPHA"                     # DEVELOP,ALPHA, BETA, RC1, RC2, RC3... RELEASE
RELEASEDATE="2019.12.24"                # release date.  must be YYYY.MM.DD
     AUTHOR="Ray Arachelian"            # name of the author
  AUTHEMAIL="ray@arachelian.com"        # email address for this software
    COMPANY="Sunder.NET"                # company (vendor for sun pkg)
      CONAM="SUNDERNET"                 # company short name for Solaris pkgs
        URL="http://lisaem.sunder.net"  # url to website of package
COPYRIGHTYEAR="2019"
COPYRIGHTLINE="Copyright © ${COPYRIGHTYEAR} Ray Arachelian, All Rights Reserved"
# ----------------------------------------------------------------------------------------
# vars auto built from the above.
VERSION="${VER}-${STABILITY}_${RELEASEDATE}"
BUILDDIR="${LCNAME}-${VER}"             # this should match the base directory name

# copy the arguements given to us as they'll be used again when we make packages
BUILDARGS="$0 $@"
export VER STABILITY RELEASEDATE AUTHOR SOFTWARE LCNAME DESCRIPTION COMPANY CONAM URL VERSION BUILDDIR BUILDARGS 

#------------------------------------------------------------------------------------------#
# end of standard section for all build scripts.
#------------------------------------------------------------------------------------------#

# you'll have to rewrite (or at least customize) the rest of this script in a similar manner for your own package

# ensure the sub-builds are executables
chmod 755 src/lib/libdc42/build.sh src/lib/libGenerator/build.sh src/tools/build.sh  2>/dev/null

#--------------------------------------------------------------------------------------------------------
# this was old way of version tracking, left here for historical reference as to release dates
#--------------------------------------------------------------------------------------------------------

#VERSION="1.2.7-ALPHA_2019.11.11"
#VERSION="1.2.7-ALPHA_2019.10.20"
#VERSION="1.2.7-ALPHA_2019.10.15"
#VERSION="1.2.7-ALPHA_2019.10.13"
#VERSION="1.2.7-ALPHA_2019.09.29"
#VERSION="1.2.6.1-RELEASE_2012.12.12"
##VERSION="1.3.0-DEVELOP_2010.05.12"##dead end
#VERSION="1.2.6-RELEASE_2007.12.12"
#VERSION="1.2.5-RELEASE_2007.11.25"
#VERSION="1.2.2-RELEASE_2007.11.11"
#VERSION="1.2.0-RELEASE_2007.09.23"
#VERSION="1.0.1-DEV_2007.08.13"
#VERSION="1.0.0-RELEASE_2007.07.07"
#VERSION="1.0.0-RC2_2007.06.27"
#--------------------------------------------------------------------------------------------------------



WITHDEBUG=""             # -g for debugging, -p for profiling. -pg for both
LIBGENOPTS=""            # passthrough to libGenerator
#STATIC=--static
WITHOPTIMIZE="-O2 -ffast-math -fomit-frame-pointer"
WITHUNICODE="--unicode=yes"

#if compiling for win32, edit WXDEV path to specify the
#location of wxDev-CPP 6.10 (as a cygwin, not windows path.)
#i.e. WXDEV=/cygdrive/c/wxDEV-Cpp
#if left empty, code below will try to locate it, so only set this
#if you've installed it in a different path than the default.

#WXDEV=""


#export DEBUGCOMPILE="yes"

rm  -f $BUILDWARNINGS

function CLEAN() {
            # note we expect to be inside src at this point, and we'll make our way out as needed.
            cd "${TLD}"
            CLEANARTIFACTS "*.o" "*.a" "*.so" "*.dylib" "*.exe" .last-opts last-opts get-uintX-types "cpu68k-?.c" def68k gen68k
            rm -f src/tools/bin/*; echo "Built binaries go here " >src/tools/bin/README
            rm -f /tmp/slot.*.sh*
            rm -f ./pkg/build/*; echo "Built packages go here"    >pkg/build/README
            rm -rf ./bin/lisaem
            if [[ -n "`which ccache 2>/dev/null`" ]]; then echo -n "* "; ccache -c; fi
}

function create_unvars_c {

echo Creating unvars.c
cat <<END1 >motherboard/unvars.c
/**************************************************************************************\\
*                             Apple Lisa 2 Emulator                                    *
*                                                                                      *
*              The Lisa Emulator Project  $VERSION                    *
*                  Copyright (C) 2019 Ray A. Arachelian                                *
*                            All Rights Reserved                                       *
*                                                                                      *
*                        Reset Global Variables .c file                                *
*                                                                                      *
*            This is a stub file - actual variables are in vars.h.                     *
*        (this is autogenerated by the build script. do not hand edit.)                *
\**************************************************************************************/

#define IN_UNVARS_C 1
// include all the includes we'll (might) need (and want)
#include <vars.h>

#define REASSIGN(  a , b  , c  )  {(b) = (c);}

void unvars(void)
{

#undef GLOBAL
#undef AGLOBAL
#undef ACGLOBAL

END1
egrep 'GLOBAL\(' ../include/vars.h | grep -v '*' | grep -v AGLOBAL | grep -v '#define' | grep -v FILE | grep -v get_exs | grep -v '\[' | sed 's/GLOBAL/REASSIGN/g'  >>motherboard/unvars.c

echo "}" >> motherboard/unvars.c


cd ..
}



export COMPILEPHASE="preparing"

if [ -z "`echo $BUILDARGS | egrep -- '--quiet|--stfu'`" ]
then
  image resources/lisaem-banner.png || (
  echo 
  echo " +------------------+  Apple Lisa 2 Emulator -Unified Build Script"
  echo " |+---------+ _____ |                                             "
  echo " ||         | _____ |       LisaEm $VERSION"
  echo " ||         |  ---= |        http://lisaem.sunder.net             "
  echo " |+---------+     . |        The Lisa Emulator Project            "
  echo " +------------------+ Copyright (C) ${RELEASEDATE:0:4} Ray Arachelian"
  echo " /=______________#_=\\           All Rights Reserved               "
  echo "                     Released under the terms of the GNU GPL v2.0"
  )
fi

CHECKDIRS bashbuild bin obj resources share src src/host src/include src/lib src/lisa src/printer \
            src/storage src/tools src/lib/libGenerator src/lib/libdc42


# Parse command line options if any, overriding defaults.

for j in $@; do
  opt=`echo "$j" | sed -e 's/without/no/g' -e 's/disable/no/g' -e 's/enable-//g' -e 's/with-//g'`

  case "$opt" in
    clean)
            CLEAN;
            #if we said clean install or clean build, then do not quit, otherwise we clean and quit
            Z="`echo $@ | grep -i install``echo $@ | grep -i build`"
            if  [[ -z "$Z" ]]; then
                echo
                echo -n "Done. "
                elapsed=$(get_elapsed_time)
                [[ -n "$elapsed" ]] && echo "$elapsed seconds" || echo
                rm -f .env-*
                exit 0
            fi

  ;;
  build*)    echo ;;    #default - nothing to do here, this is the default.


  --prefix=*)     export    PREFIX="${i:9}" ;;
  --pkg-prefix=*) export PKGPREFIX="${i:9}" ;;

  install)
            if [[ -z "$CYGWIN" ]]; then
               [[ "`whoami`" != "root" ]] && echo "Need to be root to install. try: sudo ./build.sh $@" && exit 1
            else
                CygwinSudoRebuild $@
            fi
            export INSTALL=1
            ;;

  uninstall)
            if  [[ -n "$DARWIN" ]]; then
                echo Uninstall commands not yet implemented.
                exit 1
            fi

            if  [[ -n "$CYGWIN"    ]]; then
                [[ -n "$PREFIX"    ]] && echo Deleting $PREFIX    && rm -rf $PREFIX
                [[ -n "$PREFIXLIB" ]] && echo Deleting $PREFIXLIB && rm -rf $PREFIXLIB
                exit 0
            fi

            #Linux, etc.

            #PREFIX="/usr/local/bin"
            #PREFIXLIB="/usr/local/share/"

            echo Uninstalling from $PREFIX and $PREFIXLIB
            rm -rf $PREFIXLIB/lisaem/
            rm -f  $PREFIX/lisaem
            rm -f  $PREFIX/lisafsh-tool
            rm -f  $PREFIX/lisadiskinfo
            rm -f  $PREFIX/patchxenix
            exit 0

    ;;

  -64|--64)                     export SIXTYFOURBITS="--64"; 
                                export THIRTYTWOBITS="";
                                export ARCH="-m64"                        ;;

  -32|--32)                     export SIXTYFOURBITS=""; 
                                export THIRTYTWOBITS="--32"; 
                                export ARCH="-m32"                        ;;


 --no-color-warn) export GCCCOLORIZED="" ;;
 --no-tools) export NODC42TOOLS="yes" ;;
 --no-debug)
            WITHDEBUG=""
            LIBGENOPTS=""                                     ;;

 --debug|debuggery|bugger*)
            #WITHDEBUG="$WITHDEBUG -g -DIPC_COMMENTS"
            WARNINGS="-Wall -Wextra -Wno-write-strings"
            #LIBGENOPTS="$LIBGENOPTS --with-ipc-comments"
            #LIBGENOPTS="$LIBGENOPTS --with-reg-ipc-comments"
            LIBGENOPTS="$LIBGENOPTS --with-debug"             ;;

 --profile)
            WITHDEBUG="$WITHDEBUG -p"
            LIBGENOPTS="$LIBGENOPTS --with-profile"           ;;

 --static)
            STATIC="-static"                                  ;;

 --no-static)
            STATIC=""                                         ;;

 --debug*-on-start)
            LIBGENOPTS="$LIBGENOPTS --with-debug-on-start"
            WITHDEBUG="$WITHDEBUG -g -DDEBUGLOG_ON_START"
            WARNINGS="-Wall -Wno-write-strings"
            LIBGENOPTS="$LIBGENOPTS --with-ipc-comments"
            LIBGENOPTS="$LIBGENOPTS --with-reg-ipc-comments"
            LIBGENOPTS="$LIBGENOPTS --with-debug"             ;;

 --no-optimize)
            LIBGENOPTS="$LIBGENOPTS --without-optimize"
            WITHOPTIMIZE=""                                   ;;

 --trace*)
            WITHDEBUG="$WITHDEBUG -g -DIPC_COMMENTS"
            WITHTRACE="-DDEBUG -DTRACE -DIPC_COMMENTS"
            LIBGENOPTS="$LIBGENOPTS --with-tracelog"
            LIBGENOPTS="$LIBGENOPTS --with-ipc-comments"
            LIBGENOPTS="$LIBGENOPTS --with-reg-ipc-comments"
            WARNINGS="-Wall -Wno-write-strings"               ;;

 --showcmd) DEBUGCOMPILE="yes"                                ;;
 --debug-mem*|--mem*)
            WITHDEBUG="$WITHDEBUG -g -DIPC_COMMENTS"
            WITHTRACE="-DDEBUG -DTRACE -DDEBUGMEMCALLS"
            LIBGENOPTS="$LIBGENOPTS --with-tracelog"
            LIBGENOPTS="$LIBGENOPTS --with-debug-mem"
            LIBGENOPTS="$LIBGENOPTS --with-ipc-comments"
            LIBGENOPTS="$LIBGENOPTS --with-reg-ipc-comments"
            WARNINGS="-Wall -Wno-write-strings"               ;;

 --no-68kflag-opt*)
            LIBGENOPTS="$LIBGENOPTS --no-68kflag-optimize"    ;;

 --no-upx)
            WITHOUTUPX="noupx"                                ;;

 --no-strip)
            WITHOUTSTRIP="nostrip"                            ;;

 --rawbit*)
            WITHBLITS="-DUSE_RAW_BITMAP_ACCESS"               ;;

 --no-rawbit*)
            WITHBLITS="-DNO_RAW_BITMAP_ACCESS"                ;;
 --quiet*|--stfu)
            QUIET="YES"                                       ;;

 *)                        UNKNOWNOPT="$UNKNOWNOPT $i"                       ;;
 esac

done

LIBGENOPTS="$LIBGENOPTS"

if [[ -n "$UNKNOWNOPT" ]]; then
 echo
 echo "Unknown options $UNKNOWNOPT"
 cat <<ENDHELP

Commands:
  clean                 Removes all compiled objects, libs, executables
  build                 Compiles lisaemm, libraries, and tools (default)
  clean build           Remove existing objects, compile everything cleanly
  install               Not yet implemented on all platforms
  uninstall             Not yet implemented on all platforms
  package               Build a package (Not yet implemented everywhere)

Options:
--without-debug         Disables debug and profiling
--with-debug            Enables symbol compilation
--with-tracelog         Enable tracelog (needs debug on, not on win32)
--with-debug-mem        Enables debug and tracelog and memory fn debugging
--with-debug-on-start   Enable debug output as soon as libGenerator is invoked
--no-color-warn         don't record color ESC codes in compiler warnings
--no-tools              don't compile dc42 tool commands

--with-showcmd          Show invoked compiler/linker commandlines
--with-static           Enables a static compile
--without-static        Enables shared library compile (not recommended)
--without-optimize      Disables optimizations
--without-upx           Disables UPX compression (no upx on OS X)

--without-strip         Disable strip when compiling without debug

Environment Variables you can pass:

CC                      Path to C Compiler
CPP                     Path to C++ Compiler
WXDEV                   Cygwin Path to wxDev-CPP 6.10 (win32 only)
PREFIX                  Installation directory
NUMCPUS                 override the number of CPUs - Set to 1 to only use 1

i.e. CC=/usr/local/bin/gcc ./build.sh ...

ENDHELP
# --64                 experimental for OS X 10.6
exit 1

fi


# allow versions of LisaEm compiled under Linux, *BSD, etc. to run as compiled
# without being installed.  (Some versions of wxWidgets look for the lowercase name, others, upper)
cd ${XTLD}/share || ( echo "Could not find ../share from $(/bin/pwd)" 1>&2; exit 1 )
ln -sf ../resources lisaem
ln -sf ../resources LisaEm
cd ..

[[ -n "${WITHDEBUG}${WITHTRACE}" ]] && if [[ -n "$INSTALL" ]];
then
    echo "Warning, will not install since debug/profile/trace options are enabled"
    echo "as Install command is only for production builds."
    INSTALL=""
fi

if [[ -n "${WITHDEBUG}${WITHTRACE}" ]]
then
  WITHOPTIMIZE="-O2 -ffast-math"
fi
cd ./src || exit 1
if needed include/vars.h lisa/motherboard/unvars.c
then
cd ./lisa || exit 1



create_unvars_c
fi


# Has the configuration changed since last time? if so we may need to do a clean build.
[ -f .last-opts ] && source .last-opts

needclean=0
#debug and tracelog changes affect the whole project, so need to clean it all
[[ "$WITHTRACE" != "$LASTTRACE" ]] && needclean=1
[[ "$WITHDEBUG" != "$LASTDEBUG" ]] && needclean=1
[[ "$SIXTYFOURBITS" != "$LASTSIXTYFOURBITS" ]] && needclean=1
[[ "$THIRTYTWOITS" != "$LASTTHIRTYTWOBITS" ]] && needclean=1

# display mode changes affect only the main executable, mark it for recomoilation
if [[ "$WITHBLITS" != "$LASTBLITS" ]]; then
  # rm -rf ./lisa/lisaem_wx.o ./lisa/lisaem ./lisa/lisaem.exe ./lisa/LisaEm.app;
  touch host/wxui/lisaem_wx.cpp
fi

[[ "$needclean" -gt 0 ]] && CLEAN

echo "LASTTRACE=\"$WITHTRACE\""  > .last-opts
echo "LASTDEBUG=\"$WITHDEBUG\""  >>.last-opts
echo "LASTBLITS=\"$WITHBLITS\""  >>.last-opts
echo "LASTTHIRTYTWOBITS=\"$LASTTHIRTYTWOBITS\""  >>.last-opts
echo "LASTSIXTYFOURBITS=\"$LASTSIXTYFOURBITS\""  >>.last-opts

export CFLAGS="$ARCH $CFLAGS"
export CPPFLAGS="$ARCH $CPPFLAGS"
export CXXFLAGS="$ARCH $CXXFLAGS"

###########################################################################
echo Building prerequisites...
echo

create_builtby

create_machine_h

cd "${TLD}/src"
if [[ -f   include/machine.h ]]; then
    ln -sf include/machine.h tools/include/machine.h
    ln -sf include/machine.h lib/libGenerator/include/machine.h    
    ln -sf include/machine.h lib/libdc42/include/machine.h       
else
    echo "machine.h failed to create $(pwd)" 1>&2
    exit 1
fi
cd ${TLD}
# Build libraries and tools using subbuild
export COMPILEPHASE="libGenerator"
export PERCENTPROGRESS=0 PERCENTCEILING=25 REUSESAVE=""
subbuild src/lib/libGenerator --no-banner $LIBGENOPTS $SIXTYFOURBITS $THIRTYTWOBITS skipinstall
unset LIST

export COMPILEPHASE="libdc42"
export PERCENTPROGRESS=25 PERCENTCEILING=27 REUSESAVE="yes"
subbuild src/lib/libdc42      --no-banner             $SIXTYFOURBITS $THIRTYTWOBITS skipinstall
unset LIST

if  [[ -z "$NODC42TOOLS" ]]; then
    export COMPILEPHASE="tools"
    export PERCENTPROGRESS=27 PERCENTCEILING=35 REUSESAVE="yes"
    subbuild src/tools            --no-banner             $SIXTYFOURBITS $THIRTYTWOBITS
    unset LIST
fi

echo "Building LisaEm..."
echo
echo "* LisaEm C Code                (./lisa)"


# Compile C
export COMPILEPHASE="C code"
export PERCENTPROCESS=35 PERCENTCEILING=75 PERCENTJOB=0 NUMJOBSINPHASE=15
export COMPILECOMMAND="$CC -W $WARNINGS -Wstrict-prototypes -Wno-format -Wno-unused $WITHDEBUG $WITHTRACE $CFLAGS $INC -c :INFILE:.c -o :OUTFILE:.o"
LIST1=$(WAIT="" INEXT=c OUTEXT=o OBJDIR=obj VERB=Compiling COMPILELIST \
    src/lisa/io_board/floppy          \
    src/storage/profile               \
    src/lisa/motherboard/unvars       \
    src/lisa/motherboard/vars         \
    src/lisa/motherboard/glue         \
    src/lisa/motherboard/fliflo_queue \
    src/lisa/io_board/cops            \
    src/lisa/io_board/zilog8530       \
    src/lisa/io_board/via6522         \
    src/lisa/cpu_board/irq            \
    src/lisa/cpu_board/mmu            \
    src/lisa/cpu_board/rom            \
    src/lisa/cpu_board/romless        \
    src/lisa/cpu_board/memory         \
    src/lisa/motherboard/symbols
)


cd src/host || (echo "Couldn't cd into host from $(/bin/pwd)" 1>&2; exit 1)

export WINDOWS_RES_ICONS=$( printf 'lisa2icon   ICON   "lisa2icon.ico"\r\n')
# used to have these too, but now switched to skins and PNGs, can use printf
# to print multiple lines into that var.
#//floppy0   BITMAP "floppy0.bmp"
#//floppy1   BITMAP "floppy1.bmp"
#//floppy2   BITMAP "floppy2.bmp"
#//floppy3   BITMAP "floppy3.bmp"
#//floppyN   BITMAP "floppyN.bmp"
#//lisaface0 BITMAP "lisaface0.bmp"
#//lisaface1 BITMAP "lisaface1.bmp"
#//lisaface2 BITMAP "lisaface2.bmp"
#//lisaface3 BITMAP "lisaface3.bmp"
#//power_off BITMAP "power_off.bmp"
#//power_on  BITMAP "power_on.bmp"

printf ' \r'  # eat twirly cursor, since we're not waitqing

if needed lisaem_static_resources.cpp ${TLD}/obj/lisaem_static_resources.o; then
  qjob "!!  Compiling lisaem_static_resources.cpp " $CXX $ARCH $CXXFLAGS -c lisaem_static_resources.cpp -o ${TLD}/obj/lisaem_static_resources.o
fi

printf ' \r'

LIST="$LIST ${TLD}/obj/lisaem_static_resources.o $(windres)"
# ^^ this also creates the windows resource via the windres function for Windows only. windres fn must be empty elsewhere
# note the $(windres) is executing that function call
rm -f lisaem lisaem.exe
#vars.c must be linked in before any C++ source code or else there will be linking conflicts!

cd .. || exit 1
echo
printf ' \r'
echo "* wxWidgets C++ Code           (./wxui)"

# save WARNINGS settings, add C++ extra warnings
if [[ -n "$WARNINGS" ]]; then
  OWARNINGS="$WARNINGS"
  WARNINGS="$WARNINGS -Weffc++"
fi

# Compile C++
cd "${TLD}"
export COMPILEPHASE="C++ code"
export PERCENTPROCESS=75 PERCENTCEILING=98 PERCENTJOB=0 NUMJOBSINPHASE=6
CXXFLAGS="$CXXFLAGS -I src/include -I resources"
export COMPILECOMMAND="$CXX -W -Wno-write-strings $WARNINGS $WITHDEBUG $WITHTRACE $WITHBLITS $INC $CXXFLAGS -c :INFILE:.cpp -o :OUTFILE:.o "
LIST=$( WAIT="yes" INEXT=cpp OUTEXT=o OBJDIR=obj VERB=Compiling COMPILELIST \
          src/host/wxui/lisaem_wx:src/include/vars.h:src/host/wxui/include/LisaConfig.h:src/host/wxui/include/LisaConfigFrame.h:src/host/wxui/include/LisaSkin.h:./src/printer/imagewriter/include/imagewriter-wx.h                                                  \
          src/host/wxui/LisaConfig:src/host/wxui/include/LisaConfig.h \
          src/host/wxui/LisaConfigFrame:src/host/wxui/include/LisaConfigFrame.h \
          src/host/wxui/LisaSkin:src/host/wxui/include/LisaSkin.h \
          src/lisa/crt/hqx/hq3x:src/lisa/crt/hqx/include/common.h:src/lisa/crt/hqx/include/hqx.h \
          src/printer/imagewriter/imagewriter-wx:./src/printer/imagewriter/include/imagewriter-wx.h)
# restore warnings
[ -n "$OWARNINGS" ] && WARNINGS="$OWARNINGS"


for i in `echo $LIST`; do WXLIST="$WXLIST `echo $i|grep -v lisaem_wx`"; done

echo
echo '---------------------------------------------------------------' >> $BUILDWARNINGS

cd "${TLD}"

[[ -n "$DARWIN" ]] && LISANAME="LisaEm" || LISANAME="lisaem${EXT}"

export COMPILEPHASE="linking"
export PERCENTPROCESS=98 PERCENTCEILING=99 PERCENTJOB=0 NUMJOBSINPHASE=1
update_progress_bar $PERCENTPROCESS $PERCENTJOB $NUMJOBSINPHASE $PERCENTCEILING
waitqall
qjob  "!!* Linking ./bin/${LISANAME}" $CXX $GUIAPP $GCCSTATIC $WITHTRACE $WITHDEBUG -o bin/$LISANAME  $LIST1 $LIST src/lib/libGenerator/lib/libGenerator.a \
      src/lib/libdc42/lib/libdc42.a  $LINKOPTS $SYSLIBS $LIBS
waitqall
export COMPILEPHASE="pack/install"
export PERCENTPROCESS=99 PERCENTCEILING=100 PERCENTJOB=0 NUMJOBSINPHASE=1
update_progress_bar $PERCENTPROCESS $PERCENTJOB $NUMJOBSINPHASE $PERCENTCEILING

cd "${TLD}/bin"
if  [[ -f "$LISANAME" ]]; then

    strip_and_compress ${LISANAME}
# .
# └── LisaEm.app
#     └── Contents
#         ├── MacOS
#         └── Resources
    
    if [[ -n "$DARWIN" ]]; then
        echo "* Creating macos X application" 1>&2
        mkdir -pm775 "${TLD}/bin/LisaEm.app/Contents/MacOS"
        mkdir -pm775 "${TLD}/bin/LisaEm.app/Contents/Resources"
        sed "s/_VERSION_/$VERSION/g" <"${TLD}/resources/Info.plist" > "${TLD}/bin/LisaEm.app/Contents/Info.plist"
        echo -n 'APPL????'          > "${TLD}/bin/LisaEm.app/Contents/PkgInfo"
        mv "${TLD}/bin/${LISANAME}"   "${TLD}/bin/LisaEm.app/Contents/MacOS/" || exit $?
        echo "* Copying Skins to app resources" 1>&2
        (cd "${TLD}/resources"; tar cpf - skins ) | (cd "${TLD}/bin/LisaEm.app/Contents/Resources"; tar xpf - )
        x=$?
        if  [[ "$x" -ne 0 ]]; then
            echo "Failed to copy ${TLD}/resources/skins to ${TLD}/bin/LisaEm.app/Contents/Resources" 1>&2
            exit $x
        fi
    
        [[ -n "$WITHDEBUG" ]] && echo run >gdb-run && $GDB ./LisaEm.app/Contents/MacOS/LisaEm
        #if we turned on profiling, process the results
        if [[ `echo "$WITHDEBUG" | grep 'p' >/dev/null 2>/dev/null` ]];then
          $GPROF LisaEm.app/Contents/MacOS/LisaEm/lisaem >lisaem-gprof-out
          echo lisaem-gprof-out created.
        fi
    
        if [[ -n "$INSTALL" ]]; then
          echo "* Installing LisaEm.app" 1>&2
          (cd "${TLD}/bin"; tar cf - ./LisaEm.app ) | (cd "$PREFIX"; tar xf -)
          x=$?
          if  [[ "$x" -ne 0 ]]; then
              echo "Failed to copy ${TLD}/bin/LisaEm.app to ${PREFIX}" 1>&2
              exit $x
          fi
          echo "* Done Installing." 1>&2
          elapsed=$(get_elapsed_time)
          [[ -n "$elapsed" ]] && echo "$elapsed seconds" || echo
          exit 0
        fi
        echo "Done." 1>&2; exit 0
    fi
    
    
    echo
    ####
    
    if [[ -z "$WITHDEBUG" ]]; then
    
      ## Install ###################################################
      if [[ -n "$INSTALL" ]]; then
    
        if [[ -n "$CYGWIN" ]]; then
              #PREFIX   ="/cygdrive/c/Program Files/Sunder.NET/LisaEm"
              #PREFIXLIB="/cygdrive/c/Program Files/Sunder.NET/LisaEm"
              echo "* Installing skins in $PREFIXLIB/LisaEm"
              mkdir -pm755 "$PREFIX"
              (cd "${TLD}/resources"; tar cpf - skins) | (cd "$PREFIX"; tar xpf - )
              echo "* Installing lisaem.exe binary in $PREFIX/lisaem"
              cp "${TLD}/bin/lisaem.exe" "$PREFIX"
              echo -n "  Done Installing."
              elapsed=$(get_elapsed_time)
              [[ -n "$elapsed" ]] && echo "$elapsed seconds" || echo
              exit 0
        else
          #   PREFIX="/usr/local/bin"
          #   PREFIXLIB="/usr/local/share/"
    
          echo "* Installing resources in     $PREFIXLIB/lisaem" 1>&2
          mkdir -pm755 $PREFIXLIB/LisaEm/ $PREFIX
          cp ../resources/*.wav ../resources/*.png "$PREFIXLIB/lisaem/"
          echo "* Installing lisaem binary in $PREFIX/lisaem" 1>&2
          cp lisaem "$PREFIX"
          echo -n "  Done Installing." 1>&2
          elapsed=$(get_elapsed_time)
          [[ -n "$elapsed" ]] && echo "$elapsed seconds" 1>&2 || echo 1>&2
          exit 0
        fi
    
      fi     # end of  INSTALL
      ##########################################################
    
    else
    
      if [[ -z "$CYGWIN" ]]; then
        cd ../bin
        echo run >gdb-run
        $GDB lisaem      -x gdb-run
      else
        cd ../bin
        echo run >gdb-run
        $GDB lisaem.exe -x gdb-run
      fi
    
      if  [[ -n "$(echo -- $WITHDEBUG | grep p)" ]]; then
          [[ -n "$CYGWIN" ]] && $GPROF lisaem.exe >lisaem-gprof-out.txt
          [[ -z "$CYGWIN" ]] && $GPROF lisaem     >lisaem-gprof-out.txt
          echo Profiling output written to lisaem-gprof-out.txt
      fi
    
    fi
fi

if  egrep -i 'warn|error' $BUILDWARNINGS >/dev/null 2>/dev/null; then
    echo "Compiler warnings/errors were saved to: $BUILDWARNINGS" 1>&2
fi

elapsed=$(get_elapsed_time)
[[ -n "$elapsed" ]] && echo "$elapsed seconds" || echo

# As this is the top level script, it's allowed to exit. subbuilds may not!
exit 0
