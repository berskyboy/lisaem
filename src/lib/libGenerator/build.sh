#!/usr/bin/env bash

#------------------------------------------------------------------------------------------#
# Standard block for each bashbuild script - these are used for copyright notices, packages
# this standard block ends around line 45
#------------------------------------------------------------------------------------------#

set >/tmp/build-libgen.txt
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
   SOFTWARE="libGen"                       # name of the software (can contain upper case)
     LCNAME="libGen"                       # lower case name used for the directory
DESCRIPTION="The Apple Lisa Emulator"      # description of the package
        VER="0.3.4"                        # just the version number
  STABILITY="RELEASE"                      # DEVELOP,ALPHA, BETA, RC1, RC2, RC3... RELEASE
RELEASEDATE="2019.11.24"                   # release date.  must be YYYY.MM.DD
     AUTHOR="James Ponder"                 # name of the author
  AUTHEMAIL="ray@arachelian.com"           # email address for this software
    COMPANY="squish.net"                   # company (vendor for sun pkg)
      CONAM="SQUISHNET"                    # company short name for Solaris pkgs
        URL="http://squish.net/generator"  # url to website of package

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




WITHDEBUG=""             # -g for debugging, -p for profiling. -pg for both
WITH68KFLAGS="-dNORMAL_GENERATOR_FLAGS"

#STATIC=--static
WITHOPTIMIZE="-O2 -ffast-math -fomit-frame-pointer"


# turn this on by default.

for opt in $@; do [[ "$opt" == "--no-banner" ]] && NOBANNER=1; done

if [[ -z "$NOBANNER" ]]
then
  image ${XTLD}/resources/libgen-banner.png || (
    echo '. '
    echo ' \-------------------------------------------------------------'
    echo "_-\`-_                 libGenerator ${VERSION}"
    echo '    _\                                                         '
    echo '   /  |  http://squish.net/generator   http://lisaem.sunder.net'
    echo '.--|__D   Copyright (C) 2009 James Ponder, All Rights Reserved '
    echo '   /+_`*            maintained by Ray Arachelian               '
    echo '.__(__-`    Released under the terms of the GNU GPL V2.0       '
    echo '-/-------------------------------------------------------------'
    echo
  )
fi

COMPILED=""
CHECKDIRS cpu68k generator include obj lib
CHECKFILES resources/libgen-banner.png README LICENSE AUTHORS COPYING                                                                 \
   generator/snprintf.c generator/diss68k.c generator/ui_log.c generator/reg68k.c generator/cpu68k.c                                  \
   include/def68k-proto.h include/diss68k.h include/cpu68k.h include/cpu68k-inline.h include/snprintf.h include/def68k-iibs.h         \
   include/generator.h include/registers.h include/reg68k.h include/def68k-funcs.h                                                    \
   cpu68k/def68k-proto.h cpu68k/gen68k.c cpu68k/def68k-iibs.h cpu68k/def68k.c cpu68k/def68k-funcs.h cpu68k/def68k.def cpu68k/tab68k.c

create_machine_h

# Parse command line options if any, overriding defaults.
for i in $@; do

 case "$i" in
  clean)
            echo "* Removing libGenerator objects"
            CLEANARTIFACTS  "*.a" "*.o" "*.dylib" "*.so" .last-opts last-opts machine.h "*.exe" get-uintX-types "cpu68k-?.c" def68k gen68k
            rm -f /tmp/slot.*.sh*

            if [[ -n "`which ccache`" ]]; then ccache -c >/dev/null 2>/dev/null; fi

            #if we said clean install or clean build, then do not quit
            Z="`echo $@ | grep -i install``echo $@ | grep -i build`"
            [[ -z "$Z" ]] && exit 0

  ;;
 build*)    echo ;;    #default - nothing to do here, this is the default.
 install)
            if [[ -z "$CYGWIN" ]]; then
               [[ "`whoami`" != "root" ]] && echo "Need to be root to install. try: sudo ./build.sh $@" && exit 1
            else
                CygwinSudoRebuild $@
            fi
            INSTALL=1
            ;;

 skipinstall)  INSTALL="" ;;    # skip install (used to disable $INSTALL passed from TLD builds)

 uninstall)
              echo "Uninstall commands not yet implemented."
              exit 0
    ;;
#DEBUG DEBUGMEMCALLS IPC_COMMENTS

  -64|--64)                     export SIXTYFOURBITS="--64"; 
                                export THIRTYTWOBITS="";
                                export ARCH="-m64"                        ;;

  -32|--32)                     export SIXTYFOURBITS=""; 
                                export THIRTYTWOBITS="--32"; 
                                export ARCH="-m32"                        ;;

  --without-debug)              WITHDEBUG=""
                                WARNINGS=""                               ;;

  --with-debug)                 WITHDEBUG="$WITHDEBUG -g"
                                WARNINGS="-Wall"                          ;;
  --with-ipc-comments)          WITHDEBUG="$WITHDEBUG -g -DIPC_COMMENTS"
                                WARNINGS="-Wall"                          ;;
  --with-reg-ipc-comments)      WITHDEBUG="$WITHDEBUG -g -DIPC_COMMENTS -DIPC_COMMENT_REGS"
                                WARNINGS="-Wall"                          ;;

  --with-debug-on-start)        WITHDEBUG="$WITHDEBUG -g -DDEBUGLOG_ON_START"
                                                                          ;;

  --with-debug-mem)             WITHDEBUG="$WITHDEBUG -g -DDEBUGMEMCALLS"
                                WARNINGS="-Wall"                          ;;

  --with-profile)               WITHDEBUG="$WITHDEBUG -p"                 ;;

  --without-optimize)           WITHOPTIMIZE=""                           ;;
  --no-68kflag-optimize)        WITH68KFLAGS=""                           ;;


  --with-tracelog)              WITHTRACE="-DDEBUG -DTRACE"
                                WARNINGS="-Wall"                          ;;

  --no-banner)                  NOBANNER="1";                             ;;
  *)                            UNKNOWNOPT="$UNKNOWNOPT $i"               ;;
  esac
done



if [ -n "$UNKNOWNOPT" ]
then
 echo
 echo "Unknown options $UNKNOWNOPT"
 cat <<ENDHELP

Commands:
 clean                    Removes all compiled objects, libs, executables
 build                    Compiles lisaem (default)
 clean build              Remove existing objects, compile everything cleanly
 install                  Not yet implemented on all platforms
 uninstall                Not yet implemented on all platforms

Debugging Options:
--without-debug           Disables debug and profiling
--with-debug              Enables symbol compilation
--with-debug-mem          Enable memory call debugging
--with-ipc-comments       Enable IPC comments facility
--with-reg-ipc-comments   Enable IPC comments and register recording
--with-tracelog           Enable tracelog debugging
--with-debug-on-start     Turn on debug log as soon as libGenerator is started.

Other Options:
--without-optimize        Disables optimizations
--no-68kflag-optimize     Force flag calculation on every opcode
--no-banner               Suppress version/copyright banner

Environment Variables you can pass:

CC                        Path to C Compiler
CPP                       Path to C++ Compiler
WXDEV                     Cygwin Path to wxDev-CPP 6.10 (win32 only)
PREFIX                    Installation directory

i.e. CC=/usr/local/bin/gcc ./build.sh ...

ENDHELP
exit 1

fi

[[ -n "${WITHDEBUG}${WITHTRACE}" ]] && if [ -n "$INSTALL" ];
then
   echo "Warning, will not install since debug/profile/trace options are enabled"
   echo "as Install command is only for production builds."
   INSTALL=""
fi

###########################################################################

# Has the configuration changed since last time? if so we may need to do a clean build.
[ -f .last-opts ] && source .last-opts

needclean=0

MACHINE="`uname -mrsv`"
[[ "$MACHINE"   != "$LASTMACHINE" ]] && needclean=1
#debug and tracelog changes affect the whole project, so need to clean it all
[[ "$WITHTRACE" != "$LASTTRACE" ]] && needclean=1
[[ "$WITHDEBUG" != "$LASTDEBUG" ]] && needclean=1
# display mode changes affect only the main executable.

if [ "$needclean" -gt 0 ]
then

   rm -f .last-opts last-opts
   cd ./lib       && /bin/rm -f *.a *.o
   cd ../obj      && /bin/rm -f *.a *.o
   cd ../cpu68k   && /bin/rm -f *.exe def68k gen68k cpu68k-?.c
   cd ..

fi

echo "LASTTRACE=\"$WITHTRACE\""  > .last-opts
echo "LASTDEBUG=\"$WITHDEBUG\""  >>.last-opts
echo "LASTBLITS=\"$WITHBLITS\""  >>.last-opts
echo "LASTMACHINE=\"$MACHINE\""  >>.last-opts

###########################################################################
echo Building libGenerator...
echo
echo "* Generator CPU Core OpCodes   (./cpu68k)"

cd cpu68k

DEPS=0
[[ "$DEPS" -eq 0 ]] && if needed def68k-iibs.h          ../obj/cpu68k-f.o; then  DEPS=1;fi
[[ "$DEPS" -eq 0 ]] && if needed def68k.def             ../obj/cpu68k-f.o; then  DEPS=1;fi
[[ "$DEPS" -eq 0 ]] && if needed gen68k.c               ../obj/cpu68k-f.o; then  DEPS=1;fi
[[ "$DEPS" -eq 0 ]] && if needed tab68k.c               ../obj/cpu68k-f.o; then  DEPS=1;fi
[[ "$DEPS" -eq 0 ]] && if needed def68k.c               ../obj/cpu68k-f.o; then  DEPS=1;fi
[[ "$DEPS" -eq 0 ]] && if needed ../hdr/generator.h     ../obj/cpu68k-f.o; then  DEPS=1;fi

getcpus

if [[ "$DEPS" -gt 0 ]] ######################################################################
then
  export COMPILEPHASE="gen" VERB="compiling"
  export PERCENTJOB=0 NUMJOBSINPHASE=24  #/mnt/z1/RA/sxfer/lisa_projects/lisaem-irae/lisaem-1.2.7/src/lib/libGenerator/cpu68k: update_progress_bar 1 24 25 Missing parameters
  export OUTEXT=""
  export COMPILECOMMAND="$CC $CLICMD $WARNINGS -Wstrict-prototypes -Wno-format -Wno-unused $WITHDEBUG $WITHTRACE -c :INFILE:.c -o ../:OUTFILE:.o $INC $CFLAGS"
  LIST=$(WAIT="yes" INEXT=c OUTEXT=o OBJDIR=obj VERB=Compiling COMPILELIST tab68k def68k )

  cd ../obj

  $CC $CLICMD $ARC  -o def68k tab68k.o def68k.o

  cd ../cpu68k
  echo -n "  "
  ../obj/def68k || exit 1

  echo "  Compiling gen68k.c..."
  $CC $CLICMD $ARC $WITHDEBUG $WITHTRACE -c gen68k.c -o ../obj/gen68k.o $CFLAGS $INC  || exit 1

  $CC $CLICMD $ARC $M -o ../obj/gen68k ../obj/tab68k.o ../obj/gen68k.o $LIB
  echo -n "  "
  ../obj/gen68k || exit 1

  #          1         2         3         4         5         6         7
  #01234567890123456789012345678901234567890123456789012345678901234567890123456789
  #  Writing C files... 0. 1. 2. 3. 4. 5. 6. 7. 8. 9. a. b. c. d. e. f. done.

  export COMPILEPHASE="generating"
  export PERCENTJOB=2 NUMJOBSINPHASE=24
  echo -n "  Compiling cpu68k-: "
  for src in 0 1 2 3 4 5 6 7 8 9 a b c d e f; do
      #echo -n "${src}. "
      qjob    "${src}. " $CC $WITHDEBUG $WITHTRACE $INC $CFLAGS  -c cpu68k-${src}.c -o ../obj/cpu68k-${src}.o
      COMPILED="yes"
  done
  waitqall
  echo " done."


fi
###########################################################################

#Build libGenerator.a
echo
echo "* Generator CPU Library        (./generator)"
cd ../generator

DEPS=0
[[ "$DEPS" -eq 0 ]] && if  needed cpu68k.c      ../lib/libGenerator.a;then  DEPS=1; fi
[[ "$DEPS" -eq 0 ]] && if  needed reg68k.c      ../lib/libGenerator.a;then  DEPS=1; fi
[[ "$DEPS" -eq 0 ]] && if  needed diss68k.c     ../lib/libGenerator.a;then  DEPS=1; fi

export COMPILEPHASE="support"
export PERCENTJOB=18 NUMJOBSINPHASE=24
if [[ "$DEPS" -gt 0 ]]
then
for src in cpu68k reg68k diss68k ui_log; do  
    #only compile what we need, unlike ./cpu68k this is less sensitive
    if needed ${src}.c ../obj/${src}.o
    then
      qjob "!!  Compiling ${src}.c..." $CC $WITHDEBUG $WITHTRACE $INC $CFLAGS -c ${src}.c -o ../obj/${src}.o|| exit 1
      COMPILED="yes"
    fi
done
waitqall

if [[ -n "$COMPILED" ]] || [[ ! -f ../lib/libGenerator.a ]]; then
  rm -f ../lib/libGenerator*
  makelibs  ../lib libGenerator "${VERSION}" static "../obj/cpu68k.o ../obj/reg68k.o ../obj/diss68k.o ../obj/tab68k.o ../obj/ui_log.o ../obj/cpu68k-?.o" # ../obj/lib68k.${VERSION}.a"
fi
cd ../lib/

fi


###########################################################################

if [[ -n "$INSTALL" ]]
    then
      cd ../lib/
      echo Installing libGenerator
      mkdir -pm755 "$PREFIX/lib"
      cp libGenerator-$VERSION.a "$PREFIX/lib/"
      [[ -n "$DARWIN" ]] && cp libGenerator.${VERSION}.dylib "$PREFIX/lib/"
      cd "$PREFIX/lib"
      ln -sf libGenerator-$VERSION.a libGenerator.a
    fi
echo
[[ -z "$NOBANNER" ]] && echo "libGenerator build done."
true