import unittest

import options, optionsutils
import strutils
import macros

suite "optionsutils":
  var echoed: string
  proc mockEcho(input: varargs[string, `$`]) =
    echoed = input[0]
    for i in 1..input.high:
      echoed = echoed & input[i]
  var evaluated = 0
  proc dummySome(): Option[string] =
    evaluated += 1
    return some("dummy")
  proc dummyStr(): string =
    evaluated += 1
    return "dummy"

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
    check (some("Hello")?.find('l')).unsafeGet == 2

    some("Hello")?.find('l').mockEcho
    check echoed == "2"
    reset echoed

    none(string)?.find('l').mockEcho
    check echoed.len == 0
    reset echoed

    mockEcho none(string)?.find('l')
    check echoed == "None[int]"
    reset echoed

  test "existential operator and bool conversion":
    if some("Hello")?.find('l').`==` 2:
      mockEcho "This prints"
    check echoed == "This prints"
    reset echoed

    if none(string)?.find('l').`==` 2:
      echo "This doesn't"
    check echoed != "This doesn't"
    reset echoed

    proc isTwo(x: int): bool = x == 2

    if some("hello")?.find('l').isTwo:
      mockEcho "This prints"
    check echoed == "This prints"
    reset echoed

    # Check that regular Option[bool] can't be used in an if
    when compiles(if some(true): echo "Bug"):
      check false

  test "withSome":
    let x = some(100)
    withSome x:
      some y:
        check y == 100
      none:
        check false

    var res = withSome(none(int)) do:
      some _: "Hello"
      none: "No value"

    check res == "No value"

    res = withSome(some(3)) do:
      some count: "Hello".repeat(count)
      none: "No value"

    check res == "HelloHelloHello"

  test "withSome with multiple options":
    var res = withSome [some(3), some(5)]:
      some [firstPos, secondPos]:
        "Found 'o' at position: " & $firstPos & " and 'f' at position " &
          $secondPos
      none:
        "Couldn't find either 'o' or 'f'"

    check res == "Found 'o' at position: 3 and 'f' at position 5"

    withSome [some(3), some(5)]:
      some [firstPos, secondPos]:
        check firstPos == 3
        check secondPos == 5
      none:
        check false

    withSome [some(3), none(string)]:
      some [firstPos, secondPos]:
        check false
      none:
        check true

  test "withSome without side effects":
    withSome some(100):
      some x: mockEcho "Is hundred"
      none: mockEcho "No value"

    check echoed == "Is hundred"
    reset echoed

    var sideEffects = 0
    proc someWithSideEffect(): Option[int] =
      sideEffects += 1
      some(100)

    withSome([none(int), someWithSideEffect()]):
      some [x, _]: mockEcho x
      none: mockEcho "No value"

    check echoed == "No value"
    reset echoed
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
    reset echoed

    type NonCaseAble = object
      val: string
    withSome some(NonCaseAble(val: "hello world")):
      some x: mockEcho x.val
      none: mockEcho "No value"

    check echoed == "hello world"
    reset echoed

  test "either":
    check(either(some("Correct"), "Wrong") == "Correct")
    check(either(none(string), "Correct") == "Correct")

  test "either without side effect":
    # Check that dummyStr isn't called when we have an option
    check(either(some("Correct"), dummyStr()) == "Correct")
    check evaluated == 0
    # Check that dummyStr is called when we don't have an option
    check(either(none(string), dummyStr()) == "dummy")
    check evaluated == 1
    reset evaluated
    # Check that dummySome is only called once when used as the some value
    check(either(dummySome(), "Wrong") == "dummy")
    check evaluated == 1
    reset evaluated

  test "wrapCall":
    let optParseInt = wrapCall: parseInt(x: string): int
    check optParseInt("10") == some(10)
    check optParseInt("bob") == none(int)

  test "wrapException":
    let optParseInt = wrapException: parseInt(x: string)
    withSome optParseInt("bob"):
      some e: check true
      none: check false

    withSome optParseInt("10"):
      some e: check false
      none: check true

  test "wrapErrorCode":
    let optParseInt = wrapErrorCode: parseInt(x: string)
    withSome optParseInt("10"):
      some e: check e == 10
      none: check false

    withSome optParseInt("0"):
      some e: check false
      none: check true

  test "toOpt":
    check toOpt(100) == some(100)
    check toOpt(some(100)) == some(100)

  test "optAnd":
    check optAnd(some("hello"), some(100)) == some(100)
    check optAnd(some("hello"), none(int)).isNone
    check optAnd(some("hello"), 100) == some(100)
    check optAnd("hello", none(int)).isNone

  test "optAnd without side effects":
    check optAnd(some("Correct"), dummyStr()) == some("dummy")
    check evaluated == 1
    reset evaluated

    check optAnd(none(int), dummyStr()).isNone
    check evaluated == 0
    reset evaluated

  test "optOr":
    check optOr(some("hello"), some("world")) == some("hello")
    check optOr(none(int), some(100)) == some(100)

  test "optOr without side effects":
    check optOr(some("hello"), some("world"), dummyStr()) == some("hello")
    check evaluated == 0
    reset evaluated

    check optOr(none(string), dummyStr()) == some("dummy")
    check evaluated == 1
    reset evaluated

  test "optCmp":
    check `==`.optCmp(some("hello"), some("world")) == none(string)
    check `!=`.optCmp(some("hello"), some("world")) == some("hello")
    check `!=`.optCmp(some("hello"), "world") == some("hello")
    check `!=`.optCmp("hello", some("world")) == some("hello")
    check `!=`.optCmp("hello", "world") == some("hello")
