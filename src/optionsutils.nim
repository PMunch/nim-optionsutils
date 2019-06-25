import options, macros

macro `?.`*(option: untyped, statements: untyped): untyped =
  ## Existential operator. Works like regular dot-chaining, but if
  ## the left had side is a ``none`` then the right hand side is not evaluated.
  ## In the case that ``statements`` return something the return type of this
  ## will be ``Option[T]`` where ``T`` is the returned type of ``statements``.
  ## If nothing is returned from ``statements`` this returns nothing.
  ##
  ## .. code-block:: nim
  ##   echo some("Hello")?.find('l') ## Prints out Some(2)
  ##   some("Hello")?.find('l').echo # Prints out 2
  ##   none(string)?.find('l').echo # Doesn't print out anything
  ##   echo none(string)?.find('l') # Prints out None[int] (return type of find)
  ##   # These also work in things like ifs
  ##   if some("Hello")?.find('l') == 2:
  ##     echo "This prints"
  ##   if none(string)?.find('l') == 2:
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
          return some(`injected`)
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
              error "When multiple options is passed all identifiers must be " &
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
  result = quote do:
    (proc (): auto =
      `body`
    )()

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
  ##   let optParseInt = wrapException: parseInt(x: string)
  ##   withSome optParseInt("bob"):
  ##     just e: echo e.msg
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
  ##     just e: echo "Got error code: ", e
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

