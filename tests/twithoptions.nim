import  optionsutils, options

proc a(a,b: Option[int]): Option[int]{.withSome.}= some(a + b)
proc b(a: Option[int]): Option[int]{.withNone.}= some(10)

assert a(some(10), none(int)) == none(int)
assert a(some(10), some(100)) == some(110)
assert b(none(int)) == some(10)
assert b(some(100)) == none(int)