local RunnerSupport = {}

function RunnerSupport.HasFailureOutput(output)
    output = tostring(output or "")
    return output:match("^lua:") ~= nil
        or output:match("\nlua:") ~= nil
        or output:find("stack traceback:", 1, true) ~= nil
        or output:match("^%s*FAIL:") ~= nil
        or output:match("\n%s*FAIL:") ~= nil
        or output:find("FAILED", 1, true) ~= nil
        or output:match("^%s*Failed:%s*[1-9]") ~= nil
        or output:match("\n%s*Failed:%s*[1-9]") ~= nil
end

function RunnerSupport.NormalizeCommandSuccess(commandOk, statusType, statusCode)
    if statusType ~= nil then
        if statusType == "exit" then
            return statusCode == 0
        end
        return false
    end

    if type(commandOk) == "boolean" then
        return commandOk
    end
    if type(commandOk) == "number" then
        return commandOk == 0
    end

    return false
end

function RunnerSupport.DidTestPass(output, commandOk, statusType, statusCode)
    if RunnerSupport.HasFailureOutput(output) then
        return false
    end
    return RunnerSupport.NormalizeCommandSuccess(commandOk, statusType, statusCode)
end

return RunnerSupport
