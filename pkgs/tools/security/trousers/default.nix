{stdenv, fetchurl, autoconf, automake, openssl}:

stdenv.mkDerivation {
  name = "trousers-0.3.11";

  src = fetchurl {
    url = https://sourceforge.net/projects/trousers/files/trousers/0.3.11/trousers-0.3.11.tar.gz;
    sha256 = "0h1gkqd64gynsshycvl3s3avp1y6sx6dkgy6ahqfm4bl8vssn3sf";
  };

  buildInputs = [ openssl ];

  patches = [ ./double-installed-man-page.patch
              ./disable-install-rule.patch ];

  meta = with stdenv.lib; {
    description = "TrouSerS is an CPL (Common Public License) licensed Trusted Computing Software Stack.";
    homepage    = http://trousers.sourceforge.net/;
    license     = licenses.cpl;
    platforms   = platforms.unix;
  };
}
