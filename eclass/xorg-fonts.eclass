# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# @ECLASS: xorg-fonts.eclass
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

# we need to inherit autotools first to get the deps
inherit autotools libtool toolchain-funcs flag-o-matic font

case "${EAPI:-0}" in
	6) ;;
	*) die "EAPI=${EAPI} is not supported" ;;
esac

# exports must be ALWAYS after inherit
EXPORT_FUNCTIONS src_prepare src_configure src_install pkg_postinst pkg_postrm

IUSE=""
HOMEPAGE="https://www.x.org/wiki/"

# @ECLASS-VARIABLE: XORG_BASE_INDIVIDUAL_URI
# @DESCRIPTION:
# Set up SRC_URI for individual modular releases. If set to an empty
# string, no SRC_URI will be provided by the eclass.
: ${XORG_BASE_INDIVIDUAL_URI="https://www.x.org/releases/individual"}

if [[ -n ${XORG_BASE_INDIVIDUAL_URI} ]]; then
	SRC_URI="${XORG_BASE_INDIVIDUAL_URI}/font/${P}.tar.bz2"
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

EAUTORECONF_DEPEND+=" >=x11-misc/util-macros-1.18"
# Required even by xorg-server
EAUTORECONF_DEPEND+=" >=media-fonts/font-util-1.2.0"

WANT_AUTOCONF="latest"
WANT_AUTOMAKE="latest"
for arch in ${XORG_EAUTORECONF_ARCHES}; do
	EAUTORECONF_DEPENDS+=" ${arch}? ( ${EAUTORECONF_DEPEND} )"
done
DEPEND+=" ${EAUTORECONF_DEPENDS}"
[[ ${XORG_EAUTORECONF} != no ]] && DEPEND+=" ${EAUTORECONF_DEPEND}"
unset EAUTORECONF_DEPENDS
unset EAUTORECONF_DEPEND

RDEPEND+=" media-fonts/encodings
x11-apps/mkfontscale
x11-apps/mkfontdir"
PDEPEND+=" media-fonts/font-alias"
DEPEND+=" >=media-fonts/font-util-1.2.0"

# @ECLASS-VARIABLE: FONT_DIR
# @DESCRIPTION:
# If you're creating a font package and the suffix of PN is not equal to
# the subdirectory of /usr/share/fonts/ it should install into, set
# FONT_DIR to that directory or directories. Set before inheriting this
# eclass.
[[ -z ${FONT_DIR} ]] && FONT_DIR=${PN##*-}

# Fix case of font directories
FONT_DIR=${FONT_DIR/ttf/TTF}
FONT_DIR=${FONT_DIR/otf/OTF}
FONT_DIR=${FONT_DIR/type1/Type1}
FONT_DIR=${FONT_DIR/speedo/Speedo}

# Set up configure options, wrapped so ebuilds can override if need be
[[ -z ${FONT_OPTIONS} ]] && FONT_OPTIONS="--with-fontdir=\"${EPREFIX}/usr/share/fonts/${FONT_DIR}\""

[[ ${PN##*-} = misc || ${PN##*-} = 75dpi || ${PN##*-} = 100dpi || ${PN##*-} = cyrillic ]] && IUSE+=" nls"

DEPEND+=" virtual/pkgconfig"

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

DEPEND+=" ${COMMON_DEPEND}"
RDEPEND+=" ${COMMON_DEPEND}"
unset COMMON_DEPEND

debug-print "${LINENO} ${ECLASS} ${FUNCNAME}: DEPEND=${DEPEND}"
debug-print "${LINENO} ${ECLASS} ${FUNCNAME}: RDEPEND=${RDEPEND}"
debug-print "${LINENO} ${ECLASS} ${FUNCNAME}: PDEPEND=${PDEPEND}"

# @FUNCTION: xorg-fonts_pkg_setup
# @DESCRIPTION:
# Setup prefix compat
xorg-fonts_pkg_setup() {
	debug-print-function ${FUNCNAME} "$@"

	font_pkg_setup "$@"
}

xorg-fonts_src_prepare() {
	default
	elibtoolize --patch-only
}

# @FUNCTION: xorg-fonts_font_configure
# @DESCRIPTION:
# If a font package, perform any necessary configuration steps
xorg-fonts_font_configure() {
	debug-print-function ${FUNCNAME} "$@"

	if has nls ${IUSE//+} && ! use nls; then
		if grep -q -s "disable-all-encodings" ${ECONF_SOURCE:-.}/configure; then
			FONT_OPTIONS+="
				--disable-all-encodings"
		else
			FONT_OPTIONS+="
				--disable-iso8859-2
				--disable-iso8859-3
				--disable-iso8859-4
				--disable-iso8859-5
				--disable-iso8859-6
				--disable-iso8859-7
				--disable-iso8859-8
				--disable-iso8859-9
				--disable-iso8859-10
				--disable-iso8859-11
				--disable-iso8859-12
				--disable-iso8859-13
				--disable-iso8859-14
				--disable-iso8859-15
				--disable-iso8859-16
				--disable-jisx0201
				--disable-koi8-r"
		fi
	fi
}

# @FUNCTION: xorg-fonts_flags_setup
# @DESCRIPTION:
# Set up CFLAGS for a debug build
xorg-fonts_flags_setup() {
	debug-print-function ${FUNCNAME} "$@"

	# Win32 require special define
	[[ ${CHOST} == *-winnt* ]] && append-cppflags -DWIN32 -D__STDC__
}

# @FUNCTION: xorg-fonts_src_configure
# @DESCRIPTION:
# Perform any necessary pre-configuration steps, then run configure
xorg-fonts_src_configure() {
	debug-print-function ${FUNCNAME} "$@"

	xorg-fonts_flags_setup

	xorg-fonts_font_configure

	# Check if package supports disabling of selective -Werror=...
	if grep -q -s "disable-selective-werror" ${ECONF_SOURCE:-.}/configure; then
		local selective_werror="--disable-selective-werror"
	fi

	local myeconfargs=(
		${selective_werror}
		${FONT_OPTIONS}
	)

	econf "${myeconfargs[@]}"
}


# @FUNCTION: xorg-fonts_src_install
# @DESCRIPTION:
# Install a built package to ${D}, performing any necessary steps.
# Creates a ChangeLog from git if using live ebuilds.
xorg-fonts_src_install() {
	debug-print-function ${FUNCNAME} "$@"

	dodoc ChangeLog
	default

	# Don't install libtool archives (even for modules)
	#prune_libtool_files --all
	find "${D}" -name '*.la' -delete || die

	remove_font_metadata
}

# @FUNCTION: xorg-fonts_pkg_postinst
# @DESCRIPTION:
# Run X-specific post-installation tasks on the live filesystem. The
# only task right now is some setup for font packages.
xorg-fonts_pkg_postinst() {
	debug-print-function ${FUNCNAME} "$@"

	create_fonts_scale
	create_fonts_dir
	font_pkg_postinst "$@"
}

# @FUNCTION: xorg-fonts_pkg_postrm
# @DESCRIPTION:
# Run X-specific post-removal tasks on the live filesystem. The only
# task right now is some cleanup for font packages.
xorg-fonts_pkg_postrm() {
	debug-print-function ${FUNCNAME} "$@"

	# if we're doing an upgrade, postinst will do
	if [[ -z ${REPLACED_BY_VERSION} ]]; then
		create_fonts_scale
		create_fonts_dir
		font_pkg_postrm "$@"
	fi
}

# @FUNCTION: remove_font_metadata
# @DESCRIPTION:
# Don't let the package install generated font files that may overlap
# with other packages. Instead, they're generated in pkg_postinst().
remove_font_metadata() {
	debug-print-function ${FUNCNAME} "$@"

	if [[ ${FONT_DIR} != Speedo && ${FONT_DIR} != CID ]]; then
		einfo "Removing font metadata"
		rm -rf "${ED}"/usr/share/fonts/${FONT_DIR}/fonts.{scale,dir,cache-1}
	fi
}

# @FUNCTION: create_fonts_scale
# @DESCRIPTION:
# Create fonts.scale file, used by the old server-side fonts subsystem.
create_fonts_scale() {
	debug-print-function ${FUNCNAME} "$@"

	if [[ ${FONT_DIR} != Speedo && ${FONT_DIR} != CID ]]; then
		ebegin "Generating fonts.scale"
			mkfontscale \
				-a "${EROOT}/usr/share/fonts/encodings/encodings.dir" \
				-- "${EROOT}/usr/share/fonts/${FONT_DIR}"
		eend $?
	fi
}

# @FUNCTION: create_fonts_dir
# @DESCRIPTION:
# Create fonts.dir file, used by the old server-side fonts subsystem.
create_fonts_dir() {
	debug-print-function ${FUNCNAME} "$@"

	ebegin "Generating fonts.dir"
			mkfontdir \
				-e "${EROOT}"/usr/share/fonts/encodings \
				-e "${EROOT}"/usr/share/fonts/encodings/large \
				-- "${EROOT}/usr/share/fonts/${FONT_DIR}"
	eend $?
}
