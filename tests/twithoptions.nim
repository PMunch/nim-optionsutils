import unittest

import  optionsutils, options

suite "withSome/withNone":
  test "withSome":
    proc a(a,b: Option[int], c: Option[int]): Option[int] {.withSome.} = some(a + b + c)

    check a(some(10), none(int), some(10)) == none(int)
    check a(some(10), some(100), some(10)) == some(120)

  test "withNone":
    proc b(a: Option[int]): Option[int] {.withNone.} = some(10)

    assert b(none(int)) == some(10)
    assert b(some(100)) == none(int)

  test "namedConst":
    const namedConst = some(10)
    proc a(a,b: Option[int], c: Option[int] = namedConst): Option[int] {.withSome.} = some(a + b + c)
    check a(some(10), none(int)) == none(int)
    check a(some(10), some(100)) == some(120)

  test "undef in withNone":
    when(compiles do:
      proc b(a: Option[int]): Option[int] {.withNone.} =
        echo a # This is not defined here
        some(10)
    ):
      check false
    else:
      check true

  test "withSome var argument":
    proc a(a,b: Option[int], c: var Option[int]): Option[int] {.withSome.} =
      result = some(a + b + c.get()) # `c` needs to be manually unpacked as it is a `var`
      c = none(int)

    var cIn = some(10)
    check a(some(10), none(int), cIn) == none(int)
    check cIn == some(10)

    check a(some(10), some(100), cIn) == some(120)
    check cIn == none(int)

  test "withNone var argument":
    proc b(a: var Option[int]): Option[int]{.withNone.} =
      a = some(200) # `a` is available as it was declared as a `var`
      some(10)

    var x = some(10)
    check b(x) == none(int)
    check x == some(10)
    x = none(int)
    check b(x) == some(10)
    check x == some(200)
