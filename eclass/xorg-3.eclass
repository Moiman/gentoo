# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: xorg-3.eclass
# @MAINTAINER:
# x11@gentoo.org
# @AUTHOR:
# Author: Tomáš Chvátal <scarabeus@gentoo.org>
# Author: Donnie Berkholz <dberkholz@gentoo.org>
# @BLURB: Reduces code duplication in the modularized X11 ebuilds.
# @DESCRIPTION:
# This eclass makes trivial X ebuilds possible for apps, fonts, drivers,
# and more. Many things that would normally be done in various functions
# can be accessed by setting variables instead, such as patching,
# running eautoreconf, passing options to configure and installing docs.
#
# All you need to do in a basic ebuild is inherit this eclass and set
# DESCRIPTION, KEYWORDS and RDEPEND/DEPEND. If your package is hosted
# with the other X packages, you don't need to set SRC_URI. Pretty much
# everything else should be automatic.

GIT_ECLASS=""
if [[ ${PV} == *9999* ]]; then
	GIT_ECLASS="git-r3"
	XORG_EAUTORECONF="yes"
fi

# @ECLASS-VARIABLE: XORG_MULTILIB
# @DESCRIPTION:
# If set to 'yes', the multilib support for package will be enabled. Set
# before inheriting this eclass.
: ${XORG_MULTILIB:="no"}

# we need to inherit autotools first to get the deps
inherit autotools libtool multilib toolchain-funcs \
	flag-o-matic ${GIT_ECLASS}

#if [[ ${XORG_MULTILIB} == yes ]]; then
#	inherit autotools-multilib
#fi

case "${EAPI:-0}" in
	6) ;;
	*) die "EAPI=${EAPI} is not supported" ;;
esac

# exports must be ALWAYS after inherit
EXPORT_FUNCTIONS src_prepare src_configure src_install pkg_postinst pkg_postrm

IUSE=""
HOMEPAGE="https://www.x.org/wiki/"

# @ECLASS-VARIABLE: XORG_EAUTORECONF
# @DESCRIPTION:
# If set to 'yes' and configure.ac exists, eautoreconf will run. Set
# before inheriting this eclass.
: ${XORG_EAUTORECONF:="no"}

# @ECLASS-VARIABLE: XORG_BASE_INDIVIDUAL_URI
# @DESCRIPTION:
# Set up SRC_URI for individual modular releases. If set to an empty
# string, no SRC_URI will be provided by the eclass.
: ${XORG_BASE_INDIVIDUAL_URI="https://www.x.org/releases/individual"}

# @ECLASS-VARIABLE: XORG_MODULE
# @DESCRIPTION:
# The subdirectory to download source from. Possible settings are app,
# doc, data, util, driver, font, lib, proto, xserver. Set above the
# inherit to override the default autoconfigured module.
if [[ -z ${XORG_MODULE} ]]; then
	case ${CATEGORY} in
		app-doc)             XORG_MODULE=doc/     ;;
		media-fonts)         XORG_MODULE=font/    ;;
		x11-apps|x11-wm)     XORG_MODULE=app/     ;;
		x11-misc|x11-themes) XORG_MODULE=util/    ;;
		x11-base)            XORG_MODULE=xserver/ ;;
		x11-drivers)         XORG_MODULE=driver/  ;;
		x11-proto)           XORG_MODULE=proto/   ;;
		x11-libs)            XORG_MODULE=lib/     ;;
		*)                   XORG_MODULE=         ;;
	esac
fi

# @ECLASS-VARIABLE: XORG_PACKAGE_NAME
# @DESCRIPTION:
# For git checkout the git repository might differ from package name.
# This variable can be used for proper directory specification
: ${XORG_PACKAGE_NAME:=${PN}}

if [[ -n ${GIT_ECLASS} ]]; then
	: ${EGIT_REPO_URI:="git://anongit.freedesktop.org/xorg/${XORG_MODULE}${XORG_PACKAGE_NAME} https://anongit.freedesktop.org/git/xorg/${XORG_MODULE}${XORG_PACKAGE_NAME}"}
elif [[ -n ${XORG_BASE_INDIVIDUAL_URI} ]]; then
	SRC_URI="${XORG_BASE_INDIVIDUAL_URI}/${XORG_MODULE}${P}.tar.bz2"
fi

: ${SLOT:=0}

# Set the license for the package. This can be overridden by setting
# LICENSE after the inherit. Nearly all FreeDesktop-hosted X packages
# are under the MIT license. (This is what Red Hat does in their rpms)
: ${LICENSE:=MIT}

# Set up autotools shared dependencies
# Remember that all versions here MUST be stable
XORG_EAUTORECONF_ARCHES="ppc-aix x86-winnt"
EAUTORECONF_DEPEND+="
	>=sys-devel/libtool-2.2.6a
	sys-devel/m4"
if [[ ${PN} != util-macros ]] ; then
	EAUTORECONF_DEPEND+=" >=x11-misc/util-macros-1.18"
	# Required even by xorg-server
	[[ ${PN} == "font-util" ]] || EAUTORECONF_DEPEND+=" >=media-fonts/font-util-1.2.0"
fi
WANT_AUTOCONF="latest"
WANT_AUTOMAKE="latest"
for arch in ${XORG_EAUTORECONF_ARCHES}; do
	EAUTORECONF_DEPENDS+=" ${arch}? ( ${EAUTORECONF_DEPEND} )"
done
DEPEND+=" ${EAUTORECONF_DEPENDS}"
[[ ${XORG_EAUTORECONF} != no ]] && DEPEND+=" ${EAUTORECONF_DEPEND}"
unset EAUTORECONF_DEPENDS
unset EAUTORECONF_DEPEND

# If we're a driver package, then enable DRIVER case
[[ ${PN} == xf86-video-* || ${PN} == xf86-input-* ]] && DRIVER="yes"

# @ECLASS-VARIABLE: XORG_STATIC
# @DESCRIPTION:
# Enables static-libs useflag. Set to no, if your package gets:
#
# QA: configure: WARNING: unrecognized options: --disable-static
: ${XORG_STATIC:="yes"}

# Add static-libs useflag where usefull.
if [[ ${XORG_STATIC} == yes \
		&& ${FONT} != yes \
		&& ${CATEGORY} != app-doc \
		&& ${CATEGORY} != x11-apps \
		&& ${CATEGORY} != x11-proto \
		&& ${CATEGORY} != x11-drivers \
		&& ${CATEGORY} != media-fonts \
		&& ${PN} != util-macros \
		&& ${PN} != xbitmaps \
		&& ${PN} != xorg-cf-files \
		&& ${PN/xcursor} = ${PN} ]]; then
	IUSE+=" static-libs"
fi

DEPEND+=" virtual/pkgconfig"

# @ECLASS-VARIABLE: XORG_DRI
# @DESCRIPTION:
# Possible values are "always" or the value of the useflag DRI capabilities
# are required for. Default value is "no"
#
# Eg. XORG_DRI="opengl" will pull all dri dependant deps for opengl useflag
: ${XORG_DRI:="no"}

DRI_COMMON_DEPEND="
	x11-base/xorg-server[-minimal]
	x11-libs/libdrm
"
DRI_DEPEND="
	x11-proto/xf86driproto
	x11-proto/glproto
	x11-proto/dri2proto
"
case ${XORG_DRI} in
	no)
		;;
	always)
		COMMON_DEPEND+=" ${DRI_COMMON_DEPEND}"
		DEPEND+=" ${DRI_DEPEND}"
		;;
	*)
		COMMON_DEPEND+=" ${XORG_DRI}? ( ${DRI_COMMON_DEPEND} )"
		DEPEND+=" ${XORG_DRI}? ( ${DRI_DEPEND} )"
		IUSE+=" ${XORG_DRI}"
		;;
esac
unset DRI_DEPEND
unset DRI_COMMONDEPEND

if [[ -n "${DRIVER}" ]]; then
	COMMON_DEPEND+="
		x11-base/xorg-server[xorg]
	"
fi
if [[ -n "${DRIVER}" && ${PN} == xf86-input-* ]]; then
	DEPEND+="
		x11-proto/inputproto
		x11-proto/kbproto
		x11-proto/xproto
	"
fi
if [[ -n "${DRIVER}" && ${PN} == xf86-video-* ]]; then
	COMMON_DEPEND+="
		x11-libs/libpciaccess
	"
	# we also needs some protos and libs in all cases
	DEPEND+="
		x11-proto/fontsproto
		x11-proto/randrproto
		x11-proto/renderproto
		x11-proto/videoproto
		x11-proto/xextproto
		x11-proto/xineramaproto
		x11-proto/xproto
	"
fi

# @ECLASS-VARIABLE: XORG_DOC
# @DESCRIPTION:
# Possible values are "always" or the value of the useflag doc packages
# are required for. Default value is "no"
#
# Eg. XORG_DOC="manual" will pull all doc dependant deps for manual useflag
: ${XORG_DOC:="no"}

DOC_DEPEND="
	doc? (
		app-text/asciidoc
		app-text/xmlto
		app-doc/doxygen
		app-text/docbook-xml-dtd:4.1.2
		app-text/docbook-xml-dtd:4.2
		app-text/docbook-xml-dtd:4.3
	)
"
case ${XORG_DOC} in
	no)
		;;
	always)
		DEPEND+=" ${DOC_DEPEND}"
		;;
	*)
		DEPEND+=" ${XORG_DOC}? ( ${DOC_DEPEND} )"
		IUSE+=" ${XORG_DOC}"
		;;
esac
unset DOC_DEPEND

# @ECLASS-VARIABLE: XORG_MODULE_REBUILD
# @DESCRIPTION:
# Describes whether a package contains modules that need to be rebuilt on
# xorg-server upgrade. This has an effect only since EAPI=5.
# Possible values are "yes" or "no". Default value is "yes" for packages which
# are recognized as DRIVER by this eclass and "no" for all other packages.
if [[ "${DRIVER}" == yes ]]; then
	: ${XORG_MODULE_REBUILD:="yes"}
else
	: ${XORG_MODULE_REBUILD:="no"}
fi

if [[ ${XORG_MODULE_REBUILD} == yes ]]; then
	RDEPEND+=" x11-base/xorg-server:="
fi

DEPEND+=" ${COMMON_DEPEND}"
RDEPEND+=" ${COMMON_DEPEND}"
unset COMMON_DEPEND

if [[ ${XORG_MULTILIB} == yes ]]; then
	RDEPEND+=" abi_x86_32? ( !app-emulation/emul-linux-x86-xlibs[-abi_x86_32(-)] )"
fi

debug-print "${LINENO} ${ECLASS} ${FUNCNAME}: DEPEND=${DEPEND}"
debug-print "${LINENO} ${ECLASS} ${FUNCNAME}: RDEPEND=${RDEPEND}"
debug-print "${LINENO} ${ECLASS} ${FUNCNAME}: PDEPEND=${PDEPEND}"

# @FUNCTION: xorg-3_src_prepare
# @DESCRIPTION:
# Prepare a package after unpacking, performing all X-related tasks.
xorg-3_src_prepare() {
	debug-print-function ${FUNCNAME} "$@"

	default

	case ${CHOST} in
		*-aix* | *-winnt*)
			[[ -e "./configure.ac" ]] && eautoreconf
			;;
		*)
			[[ ${XORG_EAUTORECONF} == 'yes' ]] && eautoreconf
			;;
	esac
}

# @FUNCTION: xorg-3_flags_setup
# @DESCRIPTION:
# Set up CFLAGS for a debug build
xorg-3_flags_setup() {
	debug-print-function ${FUNCNAME} "$@"

	# Win32 require special define
	[[ ${CHOST} == *-winnt* ]] && append-cppflags -DWIN32 -D__STDC__
	# hardened ldflags
	[[ ${PN} = xorg-server || -n ${DRIVER} ]] && append-ldflags -Wl,-z,lazy

	# Quite few libraries fail on runtime without these:
	if has static-libs ${IUSE//+}; then
		filter-flags -Wl,-Bdirect
		filter-ldflags -Bdirect
		filter-ldflags -Wl,-Bdirect
	fi
}

# @FUNCTION: xorg-3_src_configure
# @DESCRIPTION:
# Perform any necessary pre-configuration steps, then run configure
xorg-3_src_configure() {
	debug-print-function ${FUNCNAME} "$@"

	xorg-3_flags_setup

	# @VARIABLE: XORG_CONFIGURE_OPTIONS
	# @DESCRIPTION:
	# Array of an additional options to pass to configure.
	# @DEFAULT_UNSET
	local xorgconfadd=("${XORG_CONFIGURE_OPTIONS[@]}")

	# Check if package supports disabling of selective -Werror=...
	if grep -q -s "disable-selective-werror" ${ECONF_SOURCE:-.}/configure; then
		local selective_werror="--disable-selective-werror"
	fi

	local myeconfargs=(
		${selective_werror}
		"${xorgconfadd[@]}"
	)

	econf "${myeconfargs[@]}"
#	if [[ ${XORG_MULTILIB} == yes ]]; then
#		autotools-multilib_src_configure "$@"
#	else
#		autotools-utils_src_configure "$@"
#	fi
}


# @FUNCTION: xorg-3_src_install
# @DESCRIPTION:
# Install a built package to ${D}, performing any necessary steps.
# Creates a ChangeLog from git if using live ebuilds.
xorg-3_src_install() {
	debug-print-function ${FUNCNAME} "$@"

#	if [[ ${XORG_MULTILIB} == yes ]]; then
#		autotools-multilib_src_install "${install_args[@]}"
#	else
#		autotools-utils_src_install "${install_args[@]}"
#	fi

#	if [[ -n ${GIT_ECLASS} ]]; then
#		pushd "${EGIT_STORE_DIR}/${EGIT_CLONE_DIR}" > /dev/null || die
#		git log ${EGIT_COMMIT} > "${S}"/ChangeLog
#		popd > /dev/null || die
#	fi

	default

	# Don't install libtool archives (even for modules)
	#prune_libtool_files --all
	find "${D}" -name '*.la' -delete || die
}
