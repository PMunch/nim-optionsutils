## This module implements conveniences for dealing with the ``Option`` type in
## Nim. It is based on
## `superfuncs maybe library<https://github.com/superfunc/maybe>`_ and
## `Toccatas novel boolean approach<www.toccata.io/2017/10/No-Booleans.html>`_
## but also implements features found elsewhere.
##
## The goal of this library is to make options in Nim easier and safer to work
## with by creating good patterns for option handling.
##
##
## Usage
## =====
##
## Let's start with the example from the ``options`` module:
##
## .. code-block:: nim
##   import options
##
##   proc find(haystack: string, needle: char): Option[int] =
##     for i, c in haystack:
##       if c == needle:
##         return some(i)
##     return none(int)  # This line is actually optional,
##                       # because the default is empty
##
## .. code-block:: nim
##   let found = "abc".find('c')
##   assert found.isSome and found.get() == 2
##
## This is probably a familiar pattern, we get an option value, check if it is
## a "some" value, and then extract the actual value. But this is verbose and
## error prone. What if we refactor the code and drop the isSome check, now
## we're in a scenario where ``found.get()`` will throw an exception if we're
## not careful. This module offers a couple of alternatives:
##
## .. code-block:: nim
##   withSome found:
##     some value: echo value
##     none: discard
##
##   found?.echo
##
##   echo either(found, 0)
##
## The first way, using ``withSome`` offers a safe unpacking pattern. You pass
## it an option, or a list of options, and give it branches to evaluate when
## either all of the options are some, or any of them is a none. The benefit of
## this pattern is that the options values are unpacked into variables
## automatically in the applicable branch. This means that you can't mess up a
## refactoring and move something from the some branch into the none branch.
## And as long as care is taken to stay away from ``options.get`` and
## ``options.unsafeGet`` this will ensure you can't have exception cases.
##
## The second option is the existential operator, or optional chaining
## operator. This operator can be put where regular dot-chaining would apply
## and will only continue execution if the left-hand side is a some. In this
## example ``echo`` will only be called when ``found`` is a some, and won't
## return anything. However this also works when the right hand side might
## return something, in this case it will be wrapped in an ``Option[T]`` that
## will be a none if the left-hand side is a none.
##
## And last but not least, a simple ``either`` template. This takes an option
## and a default value, but where the regular ``options.get`` with an
## ``otherwise`` argument the default value may be a procedure that returns a
## value. This procedure will only be called if the value is a none, making
## sure that no side-effects from the procedure will happen unless it's
## necessary.
##
## This module also includes the convenient ``optCmp`` template allowing you to
## easily compare the values of two options in an option aware manner.
## So instead of having to wrap your options in one of the patterns above you
## can alse use ``optCmp`` to compare options directly:
##
## .. code-block:: nim
##   let compared = some(5).optCmp(`<`, some(10))
##
## Note however that this does not return a boolean, it returns the first value
## of the comparisson. So the above code will return a some option with the
## value 5. This means you can use them to filter values for example. And of
## course if either part of the comparisson is a none, then the result will be
## a none as well.
##
## Besides this we also have ``optAnd`` and ``optOr``, these don't work on the
## value of the option, but rather on the has-ity of the option. So ``optOr``
## will return the first some option, or a none option. And ``optAnd`` will
## return the first none option, or the last option. This can be used to
## replace boolean expressions.
##
## .. code-block:: Nim
##   let x = "green"
##   # This will print out "5"
##   echo either(optAnd(optCmp(x, `==`, "green"), 5), 3)
##   # This will print out "3"
##   echo either(optAnd(optCmp("blue", `==`, "green"), 5), 3)
##
## In the first example ``optAnd`` runs it's first expression, ``optCmp`` which
## returns an option with the value "green", since it has a value ``optAnd``
## runs the second expression ``5`` which is automatically converted to
## ``some(5)``. Since both of these have a value ``optAnd`` returns the last one
## ``some(5)``, the ``either`` procedure is just an alias for ``get`` with a
## default value, since it's first argument has a value it returns that value.
##
## In the second example ``optAnd`` runs it's first expression, ``optCmp`` which
## return an option without a value since the comparisson fails. ``optAnd`` then
## returns an option without a value, and the ``either`` procedure uses the
## default value of 3.
##
## This example is the same as a ``if x == "green": 5 else: 3`` but where x
## might not be set at all.
##
## And last but not least, in case you have a library that doesn't use options
## there are wrapper procedures that wrap exceptions and error codes in option
## returns. This is to work well with the logic operations in this module.
##
## .. code-block:: nim
##   let optParseInt = wrapCall: parseInt(x: string): int
##   echo optParseInt("10") # Prints "some(10)"
##   echo optParseInt("bob") # Prints "None[int]"
##   echo either(optParseInt("bob"), 10) # Prints 10, like a default value
##   withSome optOr(optParseInt("bob"), 10):
##     some value:
##       echo 10 # Prints 10, like a default value, but in a safe access pattern
##     none:
##       echo "No value"

import options, macros

type ExistentialOption[T] = distinct Option[T]

converter toBool*(option: ExistentialOption[bool]): bool =
  Option[bool](option).isSome and Option[bool](option).unsafeGet

converter toOption*[T](option: ExistentialOption[T]): Option[T] =
  Option[T](option)

proc toExistentialOption*[T](option: Option[T]): ExistentialOption[T] =
  ExistentialOption[T](option)

macro `?.`*(option: untyped, statements: untyped): untyped =
  ## Existential operator. Works like regular dot-chaining, but if
  ## the left had side is a ``none`` then the right hand side is not evaluated.
  ## In the case that ``statements`` return something the return type of this
  ## will be ``ExistentialOption[T]`` where ``T`` is the returned type of
  ## ``statements``. If nothing is returned from ``statements`` this returns
  ## nothing. The ``ExistentialOption[T]`` auto-converts to an ``Option[T]``
  ## and the only difference between the two is that a
  ## ``ExistentialOption[bool]`` will also auto-convert to a ``bool`` to allow
  ## it to be used in if statements.
  ##
  ## .. code-block:: nim
  ##   echo some("Hello")?.find('l') ## Prints out Some(2)
  ##   some("Hello")?.find('l').echo # Prints out 2
  ##   none(string)?.find('l').echo # Doesn't print out anything
  ##   echo none(string)?.find('l') # Prints out None[int] (return type of find)
  ##   # These also work in things like ifs as long as operator precedence is
  ##   # controlled properly:
  ##   if some("Hello")?.find('l').`==` 2:
  ##     echo "This prints"
  ##   proc equalsTwo(x: int): bool = x == 2
  ##   if some("Hello")?.find('l').equalsTwo:
  ##     echo "This also prints"
  ##   if none(string)?.find('l').`==` 2:
  ##     echo "This doesn't"
  let opt = genSym(nskLet)
  var
    injected = statements
    firstBarren = statements
  if firstBarren.len != 0:
    while true:
      if firstBarren[0].len == 0:
        firstBarren[0] = nnkDotExpr.newTree(
          nnkDotExpr.newTree(opt, newIdentNode("unsafeGet")), firstBarren[0])
        break
      firstBarren = firstBarren[0]
  else:
    injected = nnkDotExpr.newTree(
      nnkDotExpr.newTree(opt, newIdentNode("unsafeGet")), firstBarren)

  result = quote do:
    (proc (): auto {.inline.} =
      let `opt` = `option`
      if `opt`.isSome:
        when compiles(`injected`) and not compiles(some(`injected`)):
          `injected`
        else:
          return toExistentialOption(some(`injected`))
    )()

macro withSome*(options: untyped, body: untyped): untyped =
  ## Macro to require a set of options to have a value. This macro takes one or
  ## more statements that returns an option, and two cases for how to handle
  ## the cases that all the options have a value or that at least one of them
  ## doesn't. The easiest example looks something like this:
  ##
  ## .. code-block:: nim
  ##   withSome "abc".find('b'):
  ##     some pos: echo "Found 'b' at position: ", pos
  ##     none: echo "Couldn't find b"
  ##
  ## In order to minimize the nesting of these withSome blocks you can pass a
  ## list of statements that return an option to require and a list of
  ## identifiers to the ``some`` case. When doing this the statements will be
  ## executed one by one, terminating before all statements are evaluated if one
  ## doesn't return a ``some`` option:
  ##
  ## .. code-block:: nim
  ##   withSome ["abc".find('o'), "def".find('f')]:
  ##     some [firstPos, secondPos]:
  ##       echo "Found 'o' at position: ", firstPos, " and 'f' at position ",
  ##         secondPos
  ##     none: echo "Couldn't find either 'o' or 'f'"
  ##
  ## This will search for an "o" in the string "abc" which will return a
  ## ``none`` option and so we will stop, not search for "f" and run
  ## the ``none`` case. If there are any of the values we don't care about, but
  ## we still require them to exist we can shadow the identifier. All of these
  ## would be valid (this is just an example, it is not allowed to have more
  ## than one ``some`` case):
  ##
  ## .. code-block:: nim
  ##   withSome [oneThing, anotherThing]:
  ##     some [firstPos, secondPos]:
  ##     some [_, secondPos]:
  ##     some _:
  ##   withSome [oneThing]:
  ##     some pos:
  ##     some _:
  ##
  ## A withSome block can also be used to return values:
  ##
  ## .. code-block:: nim
  ##   let x = withSome(["abc".find('b'), "def".find('f')]):
  ##     some [firstPos, secondPos]: firstPos + secondPos
  ##     none: -1
  ##   echo x # Prints out "3" (1 + 2)
  var
    noneCase: NimNode = nil
    someCase: NimNode = nil
    idents: NimNode = nil
  for optionCase in body:
    case optionCase.kind:
    of nnkCall:
      if $optionCase[0] != "none":
        if $optionCase[0] != "some":
          error "Only \"none\" and \"some\" are allowed as case labels",
            optionCase[0]
        else:
          error "Only \"none\" is allowed to not have arguments", optionCase[0]
      elif noneCase != nil:
        error "Only one \"none\" case is allowed, " &
          "previously defined \"none\" case at: " & lineInfo(noneCase),
          optionCase[0]
      else:
        noneCase = optionCase[1]
    of nnkCommand:
      if $optionCase[0] != "some":
        if $optionCase[0] != "none":
          error "Only \"none\" and \"some\" are allowed as case labels",
            optionCase[0]
        else:
          error "Only \"some\" is allowed to have arguments", optionCase[0]
      elif someCase != nil:
        error "Only one \"some\" case is allowed, " &
          "previously defined \"some\" case at: " & lineInfo(someCase),
          optionCase[0]
      else:
        if optionCase[1].kind != nnkBracket and optionCase[1].kind != nnkIdent:
          error "Must have either a list or a single identifier as arguments",
            optionCase[1]
        else:
          if optionCase[1].kind == nnkBracket:
            if options.kind != nnkBracket:
              error "When only a single option is passed only a single " &
                "identifier must be supplied", optionCase[1]
            for i in optionCase[1]:
              if i.kind != nnkIdent:
                error "List must only contain identifiers", i
          elif options.kind == nnkBracket:
            if $optionCase[1] != "_":
              error "When multiple options are passed all identifiers must be " &
                "supplied", optionCase[1]
          idents = if optionCase[1].kind == nnkBracket: optionCase[1] else: newStmtList(optionCase[1])
          someCase = optionCase[2]
    else:
      error "Unrecognized structure of cases", optionCase
  if noneCase == nil:
    error "Must have a \"none\" case"
  if someCase == nil:
    error "Must have a \"some\" case"
  var body = someCase
  let optionsList = (if options.kind == nnkBracket: options else: newStmtList(options))
  for i in countdown(optionsList.len - 1, 0):
    let
      option = optionsList[i]
      tmpLet = genSym(nskLet)
      ident = if idents.len <= i: newLit("_") else: idents[i]
      assign = if $ident != "_":
        quote do:
          let `ident` = `tmpLet`.unsafeGet
      else:
        newStmtList()
    body = quote do:
      let `tmpLet` = `option`
      if `tmpLet`.isSome:
        `assign`
        `body`
      else:
        `noneCase`
  result = body
  # This doesn't work if `body` includes any reference to result..
  # It was probably done this way for a reason though
  #result = quote do:
  #  (proc (): auto =
  #    `body`
  #  )()

template either*(self, otherwise: untyped): untyped =
  ## Similar in function to ``get``, but if ``otherwise`` is a procedure it will
  ## not be evaluated if ``self`` is a ``some``. This means that ``otherwise``
  ## can have side effects.
  let opt = self # In case self is a procedure call returning an option
  if opt.isSome: opt.unsafeGet else: otherwise

macro wrapCall*(statement: untyped): untyped =
  ## Macro that wraps a procedure which can throw an exception into one that
  ## returns an option. This version takes a procedure with arguments and a
  ## return type. It returns a lambda that has the same signature as the
  ## procedure but returns an Option of the return type. The body executes the
  ## statement and returns the value if there is no exception, otherwise it
  ## returns a none option.
  ##
  ## .. code-block:: nim
  ##   let optParseInt = wrapCall: parseInt(x: string): int
  ##   echo optParseInt("10") # Prints "some(10)"
  ##   echo optParseInt("bob") # Prints "none(int)"
  assert(statement.kind == nnkStmtList)
  assert(statement[0].kind == nnkCall)
  assert(statement[0].len == 2)
  assert(statement[0][0].kind == nnkObjConstr)
  assert(statement[0][0].len >= 1)
  assert(statement[0][0][0].kind == nnkIdent)
  for i in 1 ..< statement[0][0].len:
    assert(statement[0][0][i].kind == nnkExprColonExpr)
    assert(statement[0][0][i].len == 2)
    assert(statement[0][0][i][0].kind == nnkIdent)
  assert(statement[0][1].kind == nnkStmtList)
  let T = statement[0][1][0]
  let
    procName = statement[0][0][0]
  result = quote do:
    (proc (): Option[`T`] =
      try:
        return some(`procName`())
      except:
        return none[`T`]()
    )
  # Add the arguments to the argument list of the proc and the call
  for i in 1 ..< statement[0][0].len:
    result[0][3].add nnkIdentDefs.newTree(statement[0][0][i][0], statement[0][0][i][1], newEmptyNode())
    result[0][6][0][0][0][0][1].add statement[0][0][i][0]

macro wrapException*(statement: untyped): untyped =
  ## Macro that wraps a procedure which can throw an exception into one that
  ## returns an option. This version takes a procedure with arguments but no
  ## return type. It returns a lambda that has the same signature as the
  ## procedure but returns an ``Option[ref Exception]``. The body executes the
  ## statement and returns a none option if there is no exception. Otherwise it
  ## returns a some option with the exception.
  ##
  ## .. code-block:: nim
  ##   # This might be a silly example, it's more useful for things that
  ##   # doesn't return anything
  ##   let optParseInt = wrapException: parseInt(x: string)
  ##   withSome optParseInt("bob"):
  ##     some e: echo e.msg # Prints the exception message
  ##     none: echo "Execution succeded"
  assert(statement.len == 1)
  assert(statement[0].kind == nnkObjConstr)
  assert(statement[0].len >= 1)
  assert(statement[0][0].kind == nnkIdent)
  for i in 1 ..< statement[0].len:
    assert(statement[0][i].kind == nnkExprColonExpr)
    assert(statement[0][i].len == 2)
    assert(statement[0][i][0].kind == nnkIdent)
  let
    procName = statement[0][0]
  result = quote do:
    (proc (): Option[ref Exception] =
      try:
        discard `procName`()
        return none(ref Exception)
      except:
        return some(getCurrentException())
    )
  # Add the arguments to the argument list of the proc and the call
  for i in 1 ..< statement[0].len:
    result[0][3].add nnkIdentDefs.newTree(statement[0][i][0], statement[0][i][1], newEmptyNode())
    result[0][6][0][0][0][0].add statement[0][i][0]

macro wrapErrorCode*(statement: untyped): untyped =
  ## Macro that wraps a procedure which returns an error code into one that
  ## returns an option. This version takes a procedure with arguments but no
  ## return type. It returns a lambda that has the same signature as the
  ## procedure but returns an ``Option[int]``. The body executes the
  ## statement and returns a none option if the error code is 0. Otherwise it
  ## returns a some option with the error code.
  ##
  ## .. code-block:: nim
  ##   # We cheat a bit here and use parseInt to emulate an error code
  ##   let optParseInt = wrapErrorCode: parseInt(x: string)
  ##   withSome optParseInt("10"):
  ##     some e: echo "Got error code: ", e
  ##     none: echo "Execution succeded"
  assert(statement.len == 1)
  assert(statement[0].kind == nnkObjConstr)
  assert(statement[0].len >= 1)
  assert(statement[0][0].kind == nnkIdent)
  for i in 1 ..< statement[0].len:
    assert(statement[0][i].kind == nnkExprColonExpr)
    assert(statement[0][i].len == 2)
    assert(statement[0][i][0].kind == nnkIdent)
  let
    procName = statement[0][0]
  result = quote do:
    (proc (): Option[int] =
      let eCode = `procName`()
      if eCode == 0:
        return none(int)
      else:
        return some(eCode)
    )
  # Add the arguments to the argument list of the proc and the call
  for i in 1 ..< statement[0].len:
    result[0][3].add nnkIdentDefs.newTree(statement[0][i][0], statement[0][i][1], newEmptyNode())
    result[0][6][0][0][2].add statement[0][i][0]

proc toOpt*[T](value: Option[T]): Option[T] =
  ## Procedure with overload to automatically convert something to an option if
  ## it's not already an option.
  value

proc toOpt*[T](value: T): Option[T] =
  ## Procedure with overload to automatically convert something to an option if
  ## it's not already an option.
  some(value)

macro optAnd*(options: varargs[untyped]): untyped =
  ## Goes through all options until one of them is not a some. If one of the
  ## options is not a some it returns a none, otherwise it returns the last
  ## option. Note that if some of the options are a procedure that returns an
  ## Option they won't get evaluated if an earlier option is a none. If any of
  ## the options is not an option but another type they will be converted to an
  ## option of that type automatically.
  var
    body = newStmtList()
    lastOpt: NimNode
  for option in options:
    lastOpt = genSym(nskLet)
    body.add quote do:
      let `lastOpt` = toOpt(`option`)
      if not `lastOpt`.isSome: return
  body.add quote do:
    return `lastOpt`

  result = quote do:
    (proc (): auto = `body`)()

macro optOr*(options: varargs[untyped]): untyped =
  ## Goes through the options until one of them is a some. If none of the
  ## options are a some a none is returned. Note that if some of the options are
  ## a procedure that returns an Option they won't get evaluated if an earlier
  ## option is a some. If any of the options is not an option but another type
  ## they will be converted to an option of that type automatically.
  var body = newStmtList()
  for option in options:
    body.add quote do:
      let opt = toOpt(`option`)
      if opt.isSome: return opt

  result = quote do:
    (proc (): auto = `body`)()

template optCmp*(self, cmp, value: untyped): untyped =
  ## Comparator for options. ``cmp`` must be something that accepts two
  ## parameters, ``self`` and ``value`` can either be ``Option[T]`` or ``T``.
  ## Will return ``self`` if it is an ``Option[T]`` or ``self`` converted to
  ## an ``Option[T]`` if both ``self`` and ``value`` is a some and ``cmp``
  ## returns true when called with their values.
  (proc (): auto =
    let
      a = toOpt(self)
      b = toOpt(value)
    if a.isSome and b.isSome:
      if `cmp`(a.unsafeGet, b.unsafeGet):
        return a
  )()
