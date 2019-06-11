# Maintainer: Arthur Williams <taaparthur@gmail.com>


pkgname='system-manager'
pkgver='0.4.2'
_language='en-US'
pkgrel=1
pkgdesc='System manager'

arch=('any')
license=('MIT')
depends=('jq')
makedepends=('git')
md5sums=('SKIP')

source=("git+https://github.com/TAAPArthur/system-manager.git")
_srcDir="system-manager"

package() {
  cd "$_srcDir"
  install -D -m 0755 "system-manager.sh" "$pkgdir/usr/bin/$pkgname"
  install -D -m 0755 "system-manager-autocomplete.sh" "$pkgdir/etc/bash_completion.d/system-manager-autocomplete"
  install -m 0744 -Dt "$pkgdir/usr/share/man/man1/" system-manager.1
}
