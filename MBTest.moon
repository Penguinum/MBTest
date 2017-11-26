#!/usr/bin/env moon

MBTest = {
  _VERSION: "MBTest v0.5.0"
  _DESCRIPTION: "A tiny testing library for Lua with user-defined assertions and data types."
  _LICENSE: [[
MIT License

Copyright (c) 2017 Penguinum-tea

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
  _URL: "https://github.com/Penguinum/MBTest"
}


getLine = ->
  short_src = debug.getinfo(3, 'S').short_src
  currentline = debug.getinfo(3, 'l').currentline
  return ". %s:%d"\format short_src, currentline


--- In StackOverflow we trust
deepcompare = (table1, table2) ->
  loop_cache = {}
  __compare = (a, b) ->
    if type(a) ~= type(b)
      return false
    if type(a) ~= "table"
      return a == b
    if loop_cache[a]
      return loop_cache[a] == b
    loop_cache[a] = b
    keyset = {}
    keyarr = {}
    for k in pairs b
      if type(k) == "table"
        table.insert(keyarr, k)
        keyset[k] = true
    for k_a, v_a in pairs a
      v_b = b[k_a]
      if type(k_a) == "table"
        ok = false
        for i, tk in ipairs(keyarr)
          if deepcompare(k_a, tk) and __compare(v_a, b[tk])
            table.remove(keyarr, i)
            keyset[tk] = nil
            ok = true
            break
        if not ok
          return false
      else
        if v_b == nil
          return false
        keyset[k_a] = nil
        if not __compare(v_a, v_b)
          return false
    if next(keyset)
      return false
    return true
  return __compare(table1, table2)


--- Create an object to keep "tree" of test results in it
newContext = ->
  context = {
    runs: {}
    checks: {}

    push: (name) =>
      @current.runs[name] = {
        parent: @current
        runs: {}
        checks: {}
      }
      @current = @current.runs[name]

    pop: =>
      @current = @current.parent

    addCheckResult: (result) =>
      table.insert(@current.checks, result)
  }
  context.current = context
  return context


--- Minimal MBTest instance without any registered assertions
-- @tparam table args Optional named arguments:
-- onError: function(self, message) executed if error happens during the test.
-- onFail: function(self, message) executed after the first failed test.
-- @treturn table MBTest instance
MBTest.newMBTest = (args={}) ->
  ltContext = newContext!
  fail = (msg) -> { ok: false, :msg }
  success = (msg) -> { ok: true, :msg }

  lt = {
    onError: args.onError or (msg) =>
      @stop "Error: " .. tostring(msg)
    onFail: args.onFail
  }

  if lt.onFail == "stop"
    lt.onFail = (msg) =>
      @stop msg

  if lt.onError == "stop"
    lt.onError = (msg) =>
      @stop msg

  lt.run = (name, func) ->
    if lt.stopped
      return
    ltContext\push name
    ok, ret = pcall ->
      func!
    ltContext\pop!
    if (not ok)
      if not lt.stopped
        if lt.onError
          lt\onError(ret)
        else
          error ret

  lt.stop = (msg) =>
    lt.stopped = true
    lt.result = ->
      {
        ok: false
        msg: msg
      }

  typecheckers = {}

  lt.isinstance = (value, typename) ->
    if typecheckers[typename]
      return typecheckers[typename](value)
    return type(value) == typename

  lt.registerType = (name, typechecker) ->
    typecheckers[name] = typechecker

  lt.report = ->
    getResult = (context) ->
      ret = {}
      errorMessages = {}
      localSuccessCount = 0
      checksCount = #context.checks
      runsCount = 0

      for i, v in ipairs context.checks
        if v.ok then
          localSuccessCount += 1
        else
          table.insert errorMessages, "Test #%d: %s"\format i, v.msg
      ret.errors = {}

      for _, msg in ipairs errorMessages
        table.insert ret.errors, msg
      ret.runs = {}
      for k, runInfo in pairs context.runs
        runsCount += 1
        ok, ret.runs[k] = getResult runInfo
        if ok
          localSuccessCount += 1

      ret.stats = {
        succeed: localSuccessCount,
        all: checksCount + runsCount,
      }
      ret.ok = ret.stats.succeed == ret.stats.all

      return ret.ok, ret

    _, ret = getResult ltContext
    return ret

  lt.result = ->
    indent = "-> "
    result = lt.report!
    if result.ok
      return { ok: true, msg: "All tests passed"}
    ret = { "%d/%d tests passed"\format result.stats.succeed, result.stats.all }
    _inspect = (context_name, context, depth) ->
      if not context.ok
        for _, err in ipairs(context.errors)
          table.insert(ret, indent\rep(depth) .. "[" .. context_name .. "] " .. err)
        for run_name, run_info in pairs(context.runs)
          _inspect(run_name, run_info, depth + 1)
    for run_name, run_info in pairs(result.runs)
      _inspect(run_name, run_info, 1)
    return {msg: table.concat(ret, "\n"), ok: false}

  wrapAssertion = (func, message, invert) ->
    (...) ->
      if lt.stopped
        return
      ok, succeed, msg = pcall(func, ...)
      if not ok
        ltContext\addCheckResult fail "Error: " .. tostring(succeed)
        if lt.onError
          lt\onError(succeed)
      else
        msg = msg or message
        if invert
          succeed = not succeed
        if succeed
          ltContext\addCheckResult success!
        else
          msg = msg .. " " .. getLine!
          ltContext\addCheckResult fail msg
          if lt.onFail
            lt\onFail(msg)

  lt.registerAssertion = (args) ->
    if args.name
      lt[args.name] = wrapAssertion(args.assertion, args.message)
    if args.name_inverted
      lt[args.name_inverted] = wrapAssertion(args.assertion, args.message_inverted, true)

  return lt


--- Creates MBTest instance with some useful assertions
-- @tparam table args Not used here but bypassed to MBTest constructor
-- @treturn table MBTest instance
MBTest.newExtendedMBTest = (args) ->
  lt = MBTest.newMBTest(args)

  lt.registerAssertion {
    assertion: (x, y, msg) ->
      if x == y then
        return true, msg
      else
        return false, msg
    name: "are_equal", message: "Values are not equal"
    name_inverted: "are_not_equal", message_inverted: "Values are equal"
  }

  lt.registerAssertion {
    assertion: (x, y, msg) ->
      ok = deepcompare x, y
      if ok
        return true, msg
      else
        return false, msg
    name: "are_same", message: "Deep comparison failed"
    name_inverted: "are_not_same", message_inverted: "Values are same"
  }

  lt.registerAssertion {
    assertion: (value, typenames, msg) ->
      if type(typenames) ~= "table" then
        typenames = {typenames}
      for _, typename in pairs typenames
        if lt.isinstance(value, typename)
          return true, msg
      return false, msg
    name: "is_instance", message: "Value is not instance of any of allowed types"
    name_inverted: "is_not_instance", message_inverted: "Value is instance of disallowed type"
  }

  lt.registerAssertion {
    assertion: (value, msg) ->
      if value
        return true, msg
      return false, msg

    name: "is_truthy", message: "Value is not truthy"
    name_inverted: "is_falsy", message_inverted: "Value is not falsy"
  }

  lt.registerAssertion {
    assertion: (func, msg) ->
      ok = pcall func
      if ok
        return true, msg
      return false, msg

    name: "has_no_errors", message: "Error occured"
    name_inverted: "has_errors", message_inverted: "No errors occured"
  }

  return lt


return setmetatable MBTest, {
  __call: (...) => @newExtendedMBTest(...)
}
