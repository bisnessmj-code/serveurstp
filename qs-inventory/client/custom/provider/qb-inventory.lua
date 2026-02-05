local function exportHandler(exportName, func)
    AddEventHandler(('__cfx_export_qb-inventory_%s'):format(exportName), function(setCB)
        setCB(func)
    end)
end

exportHandler('HasItem', HasItem)
