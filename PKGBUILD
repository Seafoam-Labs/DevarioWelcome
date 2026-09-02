# Maintainer: Caroline Snyder <hirpeng@gmail.com>
pkgname=devario-welcome
pkgver=0.0.1
pkgrel=1
pkgdesc="Devario OS welcome application with quick links and tooling"
arch=('x86_64' 'aarch64')
url="https://github.com/Seafoam-Labs/DevarioWelcome"
license=('GPL3')
depends=('gtk4' 'glib2')
makedepends=('zig>=0.16')
source=("${pkgname}::git+${url}.git#tag=v${pkgver}")
sha256sums=('SKIP')

build() {
    cd "$srcdir/$pkgname"
    zig build -Dcpu=baseline -Doptimize=ReleaseSafe --prefix "$srcdir/dist" install
    glib-compile-schemas data --targetdir "$srcdir/dist/share/glib-2.0/schemas"
}

package() {
    install -Dm755 "$srcdir/dist/bin/DevarioWelcome" "$pkgdir/usr/bin/devario-welcome"
    install -Dm644 "$srcdir/dist/share/glib-2.0/schemas/gschemas.compiled" \
        "$pkgdir/usr/share/glib-2.0/schemas/gschemas.compiled"
}
