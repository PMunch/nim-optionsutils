# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import options, optionsutils

suite "optionsutils":
  let intNone = none(int)
  let stringNone = none(string)
  test "existential operator":
    when not compiles(some("Hello world")?.find('w').echo):
      check false
    check (some("Hello world")?.find('w')).unsafeGet == 6
    var evaluated = false
    if (some("team")?.find('i')).unsafeGet == -1:
      evaluated = true
    check evaluated == true
    evaluated = false
    if (none(string)?.find('i')).isSome:
      evaluated = true
    check evaluated == false

  test "withSome":
    let x = some(100)
    withSome x:
      some y:
        check y == 100
      none: discard

    var res = withSome(none(int)) do:
      some _: "Hello"
      none: "No value"

    check res == "No value"

  test "withSome without side effects":
    var echoed = ""
    proc mockEcho(input: varargs[string, `$`]) =
      echoed = input[0]
      for i in 1..input.high:
        echoed = echoed & input[i]

    withSome some(100):
      some x: mockEcho "Is hundred"
      none: mockEcho "No value"

    check echoed == "Is hundred"

    var sideEffects = 0
    proc someWithSideEffect(): Option[int] =
      sideEffects += 1
      some(100)

    withSome([none(int), someWithSideEffect()]):
      some [x, _]: mockEcho x
      none: mockEcho "No value"

    check echoed == "No value"
    check sideEffects == 0

    let y = withSome([some(100), someWithSideEffect(), some(3)]):
      some [x, y, z]: (x + y) * z
      none: 0

    check y == 600
    check sideEffects == 1

    withSome([some(100), some(200)]):
      some _: mockEcho "Has value"
      none: mockEcho "No value"

    check echoed == "Has value"

    type NonCaseAble = object
      val: string
    withSome some(NonCaseAble(val: "hello world")):
      some x: mockEcho x.val
      none: mockEcho "No value"

    check echoed == "hello world"


  test "either":
    check(either(some("Correct"), "Wrong") == "Correct")
    check(either(stringNone, "Correct") == "Correct")

  test "either without side effect":
    var evaluated = 0
    proc dummySome(): Option[string] =
      evaluated += 1
      return some("dummy")
    proc dummyStr(): string =
      evaluated += 1
      return "dummy"
    # Check that dummyStr isn't called when we have an option
    check(either(some("Correct"), dummyStr()) == "Correct")
    check evaluated == 0
    # Check that dummyStr is called when we don't have an option
    check(either(stringNone, dummyStr()) == "dummy")
    check evaluated == 1
    evaluated = 0
    # Check that dummySome is only called once when used as the some value
    check(either(dummySome(), "Wrong") == "dummy")
    check evaluated == 1
