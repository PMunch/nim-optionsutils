import  optionsutils, options
const namedConst = some(10)

proc a(a,b: Option[int], c: Option[int] = namedConst): Option[int]{.withSome.}= some(a + b + c)
proc b(a: Option[int]): Option[int]{.withNone.}= some(10)

assert a(some(10), none(int)) == none(int)
assert a(some(10), some(100)) == some(120)
assert b(none(int)) == some(10)
assert b(some(100)) == none(int)