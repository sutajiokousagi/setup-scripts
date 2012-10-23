#!/bin/bash

# Original script done by Don Darling
# Later changes by Koen Kooi and Brijesh Singh

# Revision history:
# 20090902: download from twiki
# 20090903: Weakly assign MACHINE and DISTRO
# 20090904:  * Don't recreate local.conf is it already exists
#            * Pass 'unknown' machines to OE directly
# 20090918: Fix /bin/env location
#           Don't pass MACHINE via env if it's not set
#           Changed 'build' to 'bitbake' to prepare people for non-scripted usage
#           Print bitbake command it executes
# 20091012: Add argument to accept commit id.
# 20091202: Fix proxy setup
#
# For further changes consult 'git log' or browse to:
#   http://git.angstrom-distribution.org/cgi-bin/cgit.cgi/setup-scripts/
# to see the latest revision history

# Use this till we get a maintenance branch based of the release tag

umask 0002

###############################################################################
# User specific vars like proxy servers
###############################################################################

#PROXYHOST=wwwgate.ti.com
#PROXYPORT=80
PROXYHOST=""

###############################################################################
# OE_BASE    - The root directory for all OE sources and development.
###############################################################################
OE_BASE=${PWD}
# incremement this to force recreation of config files
BASE_VERSION=3


# Workaround for differences between yocto bitbake and vanilla bitbake
export BBFETCH2=True

export TAG

MACHINE=$1
shift
git checkout ${MACHINE}

#--------------------------------------------------------------------------
# If an env already exists, use it, otherwise generate it
#--------------------------------------------------------------------------

if [ -e ${OE_ENV_FILE} ] ; then
    . ${OE_ENV_FILE}
fi

if [ x"${BASE_VERSION}" != x"${SCRIPTS_BASE_VERSION}" ] ; then
	echo "BASE_VERSION mismatch, recreating ${OE_ENV_FILE}"
	rm ${OE_ENV_FILE}
fi

if [ ! -e ${OE_ENV_FILE} ] ; then
    ./oebb.sh config ${MACHINE}
fi
. ${OE_ENV_FILE}

# Update everything
./oebb.sh update


cd ${OE_BUILD_DIR}
if [ -z $MACHINE ] ; then
    echo "Executing: bitbake" $*
    exec bitbake $*
else
    echo "Executing: MACHINE=${MACHINE} bitbake" $*
    MACHINE=${MACHINE} exec bitbake $*
fi



###############################################################################
# UPDATE_OE() - Update OpenEmbedded distribution.
###############################################################################
function update_oe()
{
    if [ "x$PROXYHOST" != "x" ] ; then
        config_git_proxy
    fi

    #manage meta-openembedded and meta-angstrom with layerman
    env gawk -v command=update -f ${OE_BASE}/scripts/layers.awk ${OE_SOURCE_DIR}/layers.txt 
}



###############################################################################
# CONFIG_GIT_PROXY() - Configure GIT proxy information
###############################################################################
function config_git_proxy()
{
    if [ ! -f ${GIT_CONFIG_DIR}/git-proxy.sh ]
    then
        mkdir -p ${GIT_CONFIG_DIR}
        cat > ${GIT_CONFIG_DIR}/git-proxy.sh <<_EOF
if [ -x /bin/env ] ; then
    exec /bin/env corkscrew ${PROXYHOST} ${PROXYPORT} \$*
else
    exec /usr/bin/env corkscrew ${PROXYHOST} ${PROXYPORT} \$*
fi
_EOF
        chmod +x ${GIT_CONFIG_DIR}/git-proxy.sh
        export GIT_PROXY_COMMAND=${GIT_CONFIG_DIR}/git-proxy.sh
    fi
}

###############################################################################
# tag_layers - Tag all layers with a given tag
###############################################################################
function tag_layers()
{
    set_environment
    env gawk -v command=tag -v commandarg=$TAG -f ${OE_BASE}/scripts/layers.awk ${OE_SOURCE_DIR}/layers.txt 
    echo $TAG >> ${OE_BASE}/tags
}
