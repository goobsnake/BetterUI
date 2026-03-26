#!/bin/bash
# BetterUI Syntax Validation
# Validates all Lua files compile without syntax errors
find Modules -name '*.lua' -exec luac -p {} \; 2>&1
