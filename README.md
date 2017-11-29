# MBTest
A tiny library for testing Lua/Moonscript code. Not a serious tesing framework and doesn't aim to be one, just a module with some useful assertions and an API to create new assertions and type checkers.

It's written in Moonscript, so MBTest.moon is a source and MBTest.lua is a compiled and usable module.

## Why don't you just pick full-featured testing framework?
Because they can't be easily embedded in some sort of crazy system with its own `require` logic, no working stuff in `io` module and the whole different world. First I tried to extend [minctest-lua](https://github.com/codeplea/minctest-lua), which is very tiny and didn't require too many modifications to make it work, but now it's a completely different library.

There is plenty of [Lua tools for unit testing](http://lua-users.org/wiki/UnitTesting).
If you don't have limitations like I have then you probably should use one of them.

## Usage
```lua
local T = require "MBTest"() -- Creates a new instance of MBTest
-- You can have multiple instances with different user-defined types and assertions
-- Contexts are objects with methods, but methods are called with dot syntax.
-- `self` is not passed to them but kept in a closure.
-- I had to do this to keep compatibility with previous version that didn't have contexts.
T.run("test 1", function()
  T.run("subtest 1", function()
    T.are_same({x = 6}, {x = 5}, "Test failed: tables are not same")
  end)

  T.run("subtest 2", function()
    T.are_not_same({x = 5}, {x = 5}, "Test failed: tables are same")
  end)
end)

print(T.result().msg)
```

Also have a look at example.lua

### Full list of provided assertions
* `are_equal(val1, val2)` -- Expects values to be equal. Compares tables by reference
* `are_not_equal(val1, val2)` -- Expects values to not be equal. Compares tables by reference
* `are_same(obj1, obj2)` -- Similar to are_equal, but performs deep comparison for tables
* `are_not_same(obj1, obj2)` -- Similar to are_equal, but performs deep comparison for tables
* `is_instance(value, typename)` -- Expects value to have type `typename`.
You can also pass list of type names to check if value has some of those types.
You can register your own types using method `registerType` (see below).
* `is_not_instance(value, typename)` -- Expects value to have type `typename`.
* `is_truthy(value)` -- Expects value to not be nil or false.
* `is_falsy(value)` -- Expects value to be nil or false.
* `has_no_errors(func)` -- Runs function func and expects it to not crash.
* `has_errors(func)` -- Runs function func and expects it to crash.

Remember that you can pass custom failure message as last parameter in every assertion function.

### Registering your own types
```lua
local MBTest = require "MBTest"()
MBTest.registerType("date", function(value)
  return (type(value) == "table") and value.getYear -- An example of "heuristic" date type detection
end)
```

## TODOs
* [x] Documentation
* [ ] Unstupiditification
