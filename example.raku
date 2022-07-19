use lib ".";

use Functional;

my &split-email  = curry -> Str $email  --> Either[Str, Str]() { $email .contains("@") ?? right $email .split("@").tail !! left "Invalid email"  }
my &split-domain = curry -> Str $domain --> Either[Str, Str]() { $domain.contains(".") ?? right $domain.split(".").head !! left "Invalid domain" }

for <fernandocorrea fernandocorrea@gmail fernandocorrea@gmail.com> -> Str $email {
  right($email) >>= split-email() >>= split-domain() match {
    pattern -> Right (Str :$value) { say "\o33[32;1mOK\o33[m:  $value" }
    pattern -> Left  (Str :$value) { say "\o33[31;1mERR\o33[m: $value" }
  }
}
