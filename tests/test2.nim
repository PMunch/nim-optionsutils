import unittest

import options, optionsutils

import strutils

proc find(haystack: string, needle: char): Option[int] =
  for i, c in haystack:
    if c == needle:
      return some(i)
  return none(int)


suite "documentation examples":
  var echoed: string
  proc mockEcho(input: varargs[string, `$`]) =
    echoed = input[0]
    for i in 1..input.high:
      echoed = echoed & input[i]

  test "echo options":
    let found = "abc".find('c')
    check found.isSome and found.get() == 2

    withSome found:
      some value: mockEcho value
      none: discard
    check echoed == "2"
    reset echoed

    found?.mockEcho
    check echoed == "2"
    reset echoed

    mockEcho either(found, 0)
    check echoed == "2"
    reset echoed

  test "optCmp":
    let compared = some(5).optCmp(`<`, some(10))
    check compared == some(5)

  test "optAnd":
    let x = "green"
    # This will print out "5"
    mockEcho either(optAnd(optCmp(x, `==`, "green"), 5), 3)
    check echoed == "5"
    reset echoed
    # This will print out "3"
    mockEcho either(optAnd(optCmp("blue", `==`, "green"), 5), 3)
    check echoed == "3"
    reset echoed

  test "wrapCall":
    let optParseInt = wrapCall: parseInt(x: string): int
    when (NimMajor, NimMinor, NimPatch) >= (1, 5, 1):
      mockEcho optParseInt("10") # Prints "some(10)"
      check echoed == "some(10)"
      reset echoed

    mockEcho optParseInt("bob") # Prints "None[int]"
    when (NimMajor, NimMinor, NimPatch) >= (1, 5, 1):
      check echoed == "none(int)"
      reset echoed

    mockEcho either(optParseInt("bob"), 10) # Prints 10, like a default value
    check echoed == "10"
    reset echoed

    withSome optOr(optParseInt("bob"), 10):
      some value:
        mockEcho 10 # Prints 10, like a default value, but in a safe access pattern
      none:
        mockEcho "No value"
    check echoed == "10"
    reset echoed
