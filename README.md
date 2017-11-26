# MBTest
A tiny library for testing Lua/Moonscript code. Not a serious tesing framework and doesn't aim to be one, just a module with some useful assertions and an API to create new assertions and type checkers.

It's written in Moonscript, so MBTest.moon is a source and MBTest.lua is a compiled and usable module.

## Why don't you just pick full-featured testing framework?
Because they can't be easily embedded in some sort of crazy system with its own `require` logic, no working stuff in `io` module and the whole different world. First I tried to extend [minctest-lua](https://github.com/codeplea/minctest-lua), which is very tiny and didn't require too many modifications to make it work, but now it's a completely different library.

There are good Lua tools for testing. If you don't have limitations like I have then you probably should use them.

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

## TODOs
* [ ] Documentation
* [ ] Unstupiditification
