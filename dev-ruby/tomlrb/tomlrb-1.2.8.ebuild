# Copyright 1999-2018 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6

USE_RUBY="ruby23 ruby24 ruby25"

RUBY_FAKEGEM_RECIPE_DOC="rdoc"
RUBY_FAKEGEM_EXTRADOC="CHANGELOG.md README.md"

RUBY_FAKEGEM_BINWRAP=""

inherit ruby-fakegem

DESCRIPTION="A racc based toml parser"
HOMEPAGE="https://github.com/fbernier/tomlrb/"
SRC_URI="https://github.com/fbernier/tomlrb/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="1"
KEYWORDS="~amd64"
IUSE=""

all_ruby_prepare() {
	sed -i -e '/reporters/I s:^:#:' test/minitest_helper.rb || die
}
