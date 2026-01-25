local function SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    -- Fallback for some ZOS parametric lists that expose targetData differently
    return list.targetData
end
