--[[
File: Modules/CIM/Core/Lifecycle/DeferredTask.lua
Purpose: Managed deferred task execution with automatic cancellation.
         Replaces raw zo_callLater with trackable, cancellable tasks.

Usage:
    local tasks = BETTERUI.CIM.DeferredTask.EnsureSharedManager()
    tasks:Schedule("refreshList", 100, function()
        self:RefreshList()
    end)

    tasks:Cancel("refreshList")
    tasks:CancelAll()
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.DeferredTask = {}

-- DEFERRED TASK MANAGER CLASS

---@class DeferredTaskManager : ZO_Object
---@field _tasks table<string, number> Task ID to zo_callLater ID mapping
local DeferredTaskManager = ZO_Object:Subclass()

--- Creates a new DeferredTaskManager instance.
---@return DeferredTaskManager
function DeferredTaskManager:New()
    local obj = ZO_Object.New(self)
    obj._tasks = {}
    return obj
end

--- Schedule a deferred task with automatic previous-task cancellation.
---@param taskId string Unique identifier for the task
---@param delayMs number Delay in milliseconds before execution
---@param callback function Function to execute after delay
function DeferredTaskManager:Schedule(taskId, delayMs, callback)
    self:Cancel(taskId)

    self._tasks[taskId] = zo_callLater(function()
        self._tasks[taskId] = nil
        callback()
    end, delayMs)

    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "deferred task scheduled", { taskId = taskId, delayMs = delayMs, pending = self:GetPendingCount() }) end
end

--- Cancel a pending task if it exists.
---@param taskId string Task identifier to cancel
function DeferredTaskManager:Cancel(taskId)
    local existingId = self._tasks[taskId]
    if existingId then
        zo_removeCallLater(existingId)
        self._tasks[taskId] = nil
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "deferred task cancelled", { taskId = taskId, pending = self:GetPendingCount() }) end
end

--- Cancel all pending tasks.
--- Call this on scene exit to prevent orphaned callbacks.
function DeferredTaskManager:CancelAll()
    for taskId, _ in pairs(self._tasks) do
        self:Cancel(taskId)
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "all deferred tasks cancelled", { taskId = "*", pending = self:GetPendingCount() }) end
end

--- Check if a task is currently pending.
---@param taskId string Task identifier to check
---@return boolean pending True if the task is scheduled and not yet executed
function DeferredTaskManager:IsPending(taskId)
    return self._tasks[taskId] ~= nil
end

--- Get the count of currently pending tasks.
---@return number count Number of pending tasks
function DeferredTaskManager:GetPendingCount()
    local count = 0
    for _, _ in pairs(self._tasks) do
        count = count + 1
    end
    return count
end

-- GLOBAL INSTANCE

BETTERUI.CIM.DeferredTask.Manager = DeferredTaskManager

function BETTERUI.CIM.DeferredTask.CreateManager()
    return DeferredTaskManager:New()
end

function BETTERUI.CIM.DeferredTask.CreateLazyManagerProxy(factory)
    return setmetatable({}, {
        __index = function(_, key)
            local manager = factory()
            local value = manager and manager[key]
            if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "lazy proxy resolved", { key = key, type = type(value) }) end
            if type(value) == "function" then
                return function(_, ...)
                    return value(manager, ...)
                end
            end
            return value
        end,
        __newindex = function(_, key, value)
            local manager = factory()
            manager[key] = value
        end,
    })
end

function BETTERUI.CIM.DeferredTask.GetSharedManager()
    return BETTERUI.CIM.Tasks
end

function BETTERUI.CIM.DeferredTask.EnsureSharedManager()
    if not BETTERUI.CIM.Tasks then
        BETTERUI.CIM.Tasks = BETTERUI.CIM.DeferredTask.CreateManager()
    end

    return BETTERUI.CIM.Tasks
end
