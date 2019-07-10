import unittest

import safeoptions
import strutils

suite "safety":
  test "using safe access pattern":
    if some("Hello")?.find('l').`==` 2:
      check true
    else:
      check false
    let x = some(100)
    withSome x:
      some y:
        check y == 100
      none:
        check false

    check(either(some("Correct"), "Wrong") == "Correct")
    block wrapCallBlock:
      let optParseInt = wrapCall: parseInt(x: string): int
      check optParseInt("10") == some(10)
      check optParseInt("bob") == none(int)

    block wrapExceptionBlock:
      let optParseInt = wrapException: parseInt(x: string)
      withSome optParseInt("bob"):
        some e: check true
        none: check false

      withSome optParseInt("10"):
        some e: check false
        none: check true

    block wrapErrorCodeBlock:
      let optParseInt = wrapErrorCode: parseInt(x: string)
      withSome optParseInt("10"):
        some e: check e == 10
        none: check false

      withSome optParseInt("0"):
        some e: check false
        none: check true

    check toOpt(100) == some(100)
    check toOpt(some(100)) == some(100)

    check optAnd(some("hello"), some(100)) == some(100)
    check optAnd(some("hello"), none(int)).isNone
    check optAnd(some("hello"), 100) == some(100)
    check optAnd("hello", none(int)).isNone

    check optOr(some("hello"), some("world")) == some("hello")
    check optOr(none(int), some(100)) == some(100)

    check optCmp(some("hello"), `==`, some("world")) == none(string)
    check optCmp(some("hello"), `!=`, some("world")) == some("hello")
    check optCmp(some("hello"), `!=`, "world") == some("hello")
    check optCmp("hello", `!=`, some("world")) == some("hello")
    check optCmp("hello", `!=`, "world") == some("hello")

  test "unable to use unsafe pattern":
    when(compiles do:
      if some("Hello").find('l').isSome:
        echo "Found a value!"
      ):
      check false
    else:
      check true

    when(compiles do:
      if unsafeGet(some("Hello")) == "Hello":
        echo "Found a value!"
      ):
      check false
    else:
      check true

suite "original options":
  type RefPerson = ref object
    name: string

  proc `==`(a, b: RefPerson): bool =
    assert(not a.isNil and not b.isNil)
    a.name == b.name

  # work around a bug in unittest
  let intNone = none(int)
  let stringNone = none(string)

  test "example":
    proc find(haystack: string, needle: char): Option[int] =
      for i, c in haystack:
        if c == needle:
          return some i

    check(optCmp("abc".find('c'), `==`, 2) == some(2))

    let result = "team".find('i')

    check result == intNone
    check result.isNone

  test "some":
    check some(6).isSome
    check some("a").isSome

  test "none":
    check(none(int).isNone)
    check(not none(string).isSome)

  test "equality":
    check some("a") == some("a")
    check some(7) != some(6)
    check some("a") != stringNone
    check intNone == intNone

    when compiles(some("a") == some(5)):
      check false
    when compiles(none(string) == none(int)):
      check false

  test "$":
    check($(some("Correct")) == "Some(\"Correct\")")
    check($(stringNone) == "None[string]")

  test "map with a void result":
    var procRan = 0
    some(123).map(proc (v: int) = procRan = v)
    check procRan == 123
    intNone.map(proc (v: int) = check false)

  test "map":
    check(some(123).map(proc (v: int): int = v * 2) == some(246))
    check(intNone.map(proc (v: int): int = v * 2).isNone)

  test "filter":
    check(some(123).filter(proc (v: int): bool = v == 123) == some(123))
    check(some(456).filter(proc (v: int): bool = v == 123).isNone)
    check(intNone.filter(proc (v: int): bool = check false).isNone)

  test "flatMap":
    proc addOneIfNotZero(v: int): Option[int] =
      if v != 0:
        result = some(v + 1)
      else:
        result = none(int)

    check(some(1).flatMap(addOneIfNotZero) == some(2))
    check(some(0).flatMap(addOneIfNotZero) == none(int))
    check(some(1).flatMap(addOneIfNotZero).flatMap(addOneIfNotZero) == some(3))

    proc maybeToString(v: int): Option[string] =
      if v != 0:
        result = some($v)
      else:
        result = none(string)

    check(some(1).flatMap(maybeToString) == some("1"))

    proc maybeExclaim(v: string): Option[string] =
      if v != "":
        result = some v & "!"
      else:
        result = none(string)

    check(some(1).flatMap(maybeToString).flatMap(maybeExclaim) == some("1!"))
    check(some(0).flatMap(maybeToString).flatMap(maybeExclaim) == none(string))

  test "SomePointer":
    var intref: ref int
    check(option(intref).isNone)
    intref.new
    check(option(intref).isSome)

    let tmp = option(intref)
    check(sizeof(tmp) == sizeof(ptr int))

  test "none[T]":
    check(none[int]().isNone)
    check(none(int) == none[int]())

  test "$ on typed with .name":
    type Named = object
      name: string

    let nobody = none(Named)
    check($nobody == "None[Named]")

  test "$ on type with name()":
    type Person = object
      myname: string

    let noperson = none(Person)
    check($noperson == "None[Person]")

  test "Ref type with overloaded `==`":
    let p = some(RefPerson.new())
    check p.isSome

