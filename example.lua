#!/usr/bin/env lua

local T = require "MBTest" {
  onFail = "stop"
}

T.run("equality check", function()
  T.are_equal(1, 1)
  T.are_not_equal(1, 2)
  local a = {}
  T.are_equal(a, a)
  T.are_not_equal(a, {})
end)

T.run("deep compare", function()
  T.are_same(1, 1)
  T.are_not_same(1, 2)
  T.are_same({1}, {1})
  T.are_not_same({1}, {2})
  T.are_not_same({[1] = 1}, {[1] = 2})

  T.run("tables as keys", function()
    T.are_same({[{x = 5}] = {x = 5}}, {[{x = 5}] = {x = 5}})
    T.are_same({[{1, x = 5}] = {x = 5}}, {[{1, x = 5}] = {x = 5}})
    T.are_not_same({[{x = 6}] = {x = 5}}, {[{x = 5}] = {x = 5}})
    T.are_not_same({[{x = 5}] = {x = 5}}, {[{x = 5}] = {y = 5}})
  end)
end)


T.run("truthy/falsy", function()
  T.is_truthy(1)
  T.is_truthy(true)
  T.is_falsy(false)
  T.is_falsy(nil)
end)

T.run("check types", function()
  T.is_instance("as", "string")
  T.is_instance(1, {"number", "string"})
  T.is_not_instance(1, "string")
  T.is_not_instance(1, {"string", "table"})
end)

T.run("check custom types", function()
  T.is_not_instance({addDays = true}, "date")
  T.registerType("date", function(value)
    local _t = type(value)
    if (_t == "table" or _t == "userdata") and value.addDays then
      return true
    else
      return false
    end
  end)
  T.is_instance({addDays = true}, "date")
  T.registerType("date", nil)
  T.is_not_instance({addDays = true}, "date")
end)

T.run("errors", function()
  T.has_errors(error)
  T.has_no_errors(function() end)
end)

local report = T.result()
print(report.msg)
