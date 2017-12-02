local MBTest = {
  _VERSION = "MBTest v0.5.0",
  _DESCRIPTION = "A tiny testing library for Lua with user-defined assertions and data types.",
  _LICENSE = [[MIT License

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
]],
  _URL = "https://github.com/Penguinum/MBTest"
}
local getLine
getLine = function()
  local short_src = debug.getinfo(3, 'S').short_src
  local currentline = debug.getinfo(3, 'l').currentline
  return (". %s:%d"):format(short_src, currentline)
end
local deepcompare
deepcompare = function(table1, table2)
  local loop_cache = { }
  local __compare
  __compare = function(a, b)
    if type(a) ~= type(b) then
      return false
    end
    if type(a) ~= "table" then
      return a == b
    end
    if loop_cache[a] then
      return loop_cache[a] == b
    end
    loop_cache[a] = b
    local keyset = { }
    local keyarr = { }
    for k in pairs(b) do
      if type(k) == "table" then
        table.insert(keyarr, k)
        keyset[k] = true
      end
    end
    for k_a, v_a in pairs(a) do
      local v_b = b[k_a]
      if type(k_a) == "table" then
        local ok = false
        for i, tk in ipairs(keyarr) do
          if deepcompare(k_a, tk) and __compare(v_a, b[tk]) then
            table.remove(keyarr, i)
            keyset[tk] = nil
            ok = true
            break
          end
        end
        if not ok then
          return false
        end
      else
        if v_b == nil then
          return false
        end
        keyset[k_a] = nil
        if not __compare(v_a, v_b) then
          return false
        end
      end
    end
    if next(keyset) then
      return false
    end
    return true
  end
  return __compare(table1, table2)
end
local newContext
newContext = function()
  local context = {
    runs = { },
    checks = { },
    push = function(self, name)
      self.current.runs[name] = {
        parent = self.current,
        runs = { },
        checks = { }
      }
      self.current = self.current.runs[name]
    end,
    pop = function(self)
      self.current = self.current.parent
    end,
    addCheckResult = function(self, result)
      return table.insert(self.current.checks, result)
    end
  }
  context.current = context
  return context
end
MBTest.newMBTest = function(args)
  if args == nil then
    args = { }
  end
  local ltContext = newContext()
  local fail
  fail = function(msg)
    return {
      ok = false,
      msg = msg
    }
  end
  local success
  success = function(msg)
    return {
      ok = true,
      msg = msg
    }
  end
  local mbtest = {
    onError = args.onError or function(self, msg)
      return self:stop("Error: " .. tostring(msg))
    end,
    onFail = args.onFail
  }
  if mbtest.onFail == "stop" then
    mbtest.onFail = function(self, msg)
      return self:stop(msg)
    end
  end
  if mbtest.onError == "stop" then
    mbtest.onError = function(self, msg)
      return self:stop(msg)
    end
  end
  mbtest.run = function(name, func)
    if mbtest.stopped then
      return 
    end
    ltContext:push(name)
    local ok, ret = pcall(function()
      return func()
    end)
    ltContext:pop()
    if (not ok) then
      if not mbtest.stopped then
        if mbtest.onError then
          return mbtest:onError(ret)
        else
          return error(ret)
        end
      end
    end
  end
  mbtest.stop = function(self, msg)
    mbtest.stopped = true
    mbtest.result = function()
      return {
        ok = false,
        msg = msg
      }
    end
  end
  local typecheckers = { }
  mbtest.isinstance = function(value, typename)
    if typecheckers[typename] then
      return typecheckers[typename](value)
    end
    return type(value) == typename
  end
  mbtest.registerType = function(name, typechecker)
    typecheckers[name] = typechecker
  end
  mbtest.report = function()
    local getResult
    getResult = function(context)
      local ret = { }
      local errorMessages = { }
      local localSuccessCount = 0
      local checksCount = #context.checks
      local runsCount = 0
      for i, v in ipairs(context.checks) do
        if v.ok then
          localSuccessCount = localSuccessCount + 1
        else
          table.insert(errorMessages, ("Test #%d: %s"):format(i, v.msg))
        end
      end
      ret.errors = { }
      for _, msg in ipairs(errorMessages) do
        table.insert(ret.errors, msg)
      end
      ret.runs = { }
      for k, runInfo in pairs(context.runs) do
        runsCount = runsCount + 1
        local ok
        ok, ret.runs[k] = getResult(runInfo)
        if ok then
          localSuccessCount = localSuccessCount + 1
        end
      end
      ret.stats = {
        succeed = localSuccessCount,
        all = checksCount + runsCount
      }
      ret.ok = ret.stats.succeed == ret.stats.all
      return ret.ok, ret
    end
    local _, ret = getResult(ltContext)
    return ret
  end
  mbtest.result = function()
    local indent = "-> "
    local result = mbtest.report()
    if result.ok then
      return {
        ok = true,
        msg = "All tests passed"
      }
    end
    local ret = {
      ("%d/%d tests passed"):format(result.stats.succeed, result.stats.all)
    }
    local _inspect
    _inspect = function(context_name, context, depth)
      if not context.ok then
        for _, err in ipairs(context.errors) do
          table.insert(ret, indent:rep(depth) .. "[" .. context_name .. "] " .. err)
        end
        for run_name, run_info in pairs(context.runs) do
          _inspect(run_name, run_info, depth + 1)
        end
      end
    end
    for run_name, run_info in pairs(result.runs) do
      _inspect(run_name, run_info, 1)
    end
    return {
      msg = table.concat(ret, "\n"),
      ok = false
    }
  end
  local wrapAssertion
  wrapAssertion = function(func, message, invert)
    return function(...)
      if mbtest.stopped then
        return 
      end
      local ok, succeed, msg = pcall(func, ...)
      if not ok then
        ltContext:addCheckResult(fail("Error: " .. tostring(succeed)))
        if mbtest.onError then
          return mbtest:onError(succeed)
        end
      else
        msg = msg or message
        if invert then
          succeed = not succeed
        end
        if succeed then
          return ltContext:addCheckResult(success())
        else
          msg = msg .. " " .. getLine()
          ltContext:addCheckResult(fail(msg))
          if mbtest.onFail then
            return mbtest:onFail(msg)
          end
        end
      end
    end
  end
  mbtest.registerAssertion = function(args)
    if args.name then
      mbtest[args.name] = wrapAssertion(args.assertion, args.message)
    end
    if args.name_inverted then
      mbtest[args.name_inverted] = wrapAssertion(args.assertion, args.message_inverted, true)
    end
  end
  return mbtest
end
MBTest.newExtendedMBTest = function(args)
  local mbtest = MBTest.newMBTest(args)
  mbtest.registerAssertion({
    assertion = function(x, y, msg)
      if x == y then
        return true, msg
      else
        return false, msg
      end
    end,
    name = "are_equal",
    message = "Values are not equal",
    name_inverted = "are_not_equal",
    message_inverted = "Values are equal"
  })
  mbtest.registerAssertion({
    assertion = function(x, y, msg)
      local ok = deepcompare(x, y)
      if ok then
        return true, msg
      else
        return false, msg
      end
    end,
    name = "are_same",
    message = "Deep comparison failed",
    name_inverted = "are_not_same",
    message_inverted = "Values are same"
  })
  mbtest.registerAssertion({
    assertion = function(value, typenames, msg)
      if type(typenames) ~= "table" then
        typenames = {
          typenames
        }
      end
      for _, typename in pairs(typenames) do
        if mbtest.isinstance(value, typename) then
          return true, msg
        end
      end
      return false, msg
    end,
    name = "is_instance",
    message = "Value is not instance of any of allowed types",
    name_inverted = "is_not_instance",
    message_inverted = "Value is instance of disallowed type"
  })
  mbtest.registerAssertion({
    assertion = function(value, msg)
      if value then
        return true, msg
      end
      return false, msg
    end,
    name = "is_truthy",
    message = "Value is not truthy",
    name_inverted = "is_falsy",
    message_inverted = "Value is not falsy"
  })
  mbtest.registerAssertion({
    assertion = function(func, msg)
      local ok = pcall(func)
      if ok then
        return true, msg
      end
      return false, msg
    end,
    name = "has_no_errors",
    message = "Error occured",
    name_inverted = "has_errors",
    message_inverted = "No errors occured"
  })
  return mbtest
end
return setmetatable(MBTest, {
  __call = function(self, ...)
    return self:newExtendedMBTest(...)
  end
})
