use v6.e.PREVIEW;
class Curry does Callable {
  has &!func   is built;
  has $!orig   is built;
  has @!prefix is built;

  method CALL-ME(+@c) {
    my @new = |@!prefix, |@c;
    return self unless @c;
    do if @c >= &!func.signature.arity {
      &!func(|@c)
    } else {
      curry(:prefix(@new), :$!orig, &!func.assuming: |@c)<>;
    }<>
  }

  method gist { "{ self.^name }|{ self.WHERE }" }
  method raku { "#`({ self.gist})" }
}

sub curry (&func where { .signature.params.none.named }, :@prefix, :$orig) is export {
  Curry.new: :&func, :orig($orig // &func.WHICH), :@prefix
}

role Functor[::T = Any] {
  #method id  { ... }
  method fmap(&:(T --> Any)) { ... }
}

role Applicative[::T = Any] does Functor[T] {
  method pure(T --> Applicative[T])  { ... }
  method apply(Applicative[Callable], Applicative[T] --> Applicative[Any]) { ... }
}

role Monad[::T = Any] does Applicative[T] {
  method bind  { ... }
  method flat { ... }
  method return($value) { self.pure: $value }
  method flatmap(&func) { $.flat.fmap: &func }
}

our &fmap    is export = curry sub (&block, Functor $f)             { $f.fmap: &block }
our &apply   is export = curry sub (Applicative $a, Applicative $f) { $f.apply: $a }
our &bind    is export = curry sub (Monad $a, &func)                { $a.bind: &func }
our &flat    is export = curry sub (Monad $a)                       { $a.flat }

sub infix:«>>=»(Monad $m, &f) is tighter(&infix:<+>) is export { bind $m, &f }

role Left[$, $]  { ... }
role Right[$, $] { ... }

role Either[::L = Any, ::R = Any] does Monad {
  multi method COERCE(Left[ L,   Any] (L :$value)) { Left[ L.WHAT, R.WHAT].new: :$value }
  multi method COERCE(Right[Any, R  ] (R :$value)) { Right[L.WHAT, R.WHAT].new: :$value }
  method fmap(&:(L --> ::T)) { self }
  method pure(R)    { self }
  method apply(&)   { self }
  method flat    { self }
  method bind(&) { self }
}

role Left[::L = Any, ::R = Any] does Either[L, R] {
  has L $.value;
  method gist    { "Left($!value.raku())" }
}

role Right[::L = Any, ::R = Any] does Either[L, R] {
   has R $.value;

   method get { $!value }
   method fmap(&trans) {
     my $value = trans $!value;
     Right[L, $value.WHAT].new: :$value
   }
   method pure(R $value) {
     self.new: :$value
   }
   method apply(\func) {
     return func if func ~~ Either && func !~~ Right;
     fmap func.get, self
   }
   method flat { $.get }
   method bind(&func) {
     func $.get
   }

   method gist { "Right($.get().raku())" }
   method raku { self.gist }
}

multi either(Any:U $left, Any:D $right) is export { Right[$left,      $right.WHAT].new: :value($right) }
multi either(Any:D $left, Any:U $right) is export { Left[ $left.WHAT, $right     ].new: :value($left ) }

multi right($value) is export { Right[Any,         $value.WHAT].new: :$value }
multi left($value)  is export { Left[ $value.WHAT, Any        ].new: :$value }

role Nothing { ... }

role Maybe[::T = Any] does Monad[T] {
  multi method COERCE(Nothing[Any]) { Nothing[T.WHAT].new }
  method fmap(&) { self }
  method pure    { self }
  method apply   { self }
  method flat    { self }
  method bind(&) { self }
}

role Just[::T = Any] does Maybe[T] {
   has T $.value;

   method get { $!value }
   method fmap(&trans) {
     my $value = trans $!value;
     Just[$value.WHAT].new: :$value
   }
   method pure(T $value) {
     self.new: :$value
   }
   method apply(\func) {
     return func if func ~~ Maybe && func !~~ Just;
     fmap func.get, self
   }
   method flat { $.get }
   method bind(&func) {
     func $.get
   }

   method gist { "Just($.get().raku())" }
   method raku { self.gist }
}

role Nothing[::T = Any] does Maybe[T] {
  method gist    { "Nothing" }
}

sub just($value) is export { Just[$value.WHAT].new: :$value }
sub nothing      is export { Nothing[Any].new }

sub pattern(&block) is export {
   @*funcs.push: &block
}

multi infix:<match>($value, &block) is looser(&infix:«>>=») is export {
   my Callable @*funcs is default(Callable);
   block;
   do with @*funcs.first: { my \sign = .signature; \(|$value) ~~ sign } -> &func {
      func |$value
   } else {
      die "No pattern found"
   }
}
