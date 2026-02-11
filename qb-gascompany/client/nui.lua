RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb(true)
end)

RegisterNUICallback('toggleDuty', function(data, cb)
    TriggerEvent('qb-gascompany:client:setDuty', data.value == true)
    cb(true)
end)

RegisterNUICallback('requestMission', function(_, cb)
    TriggerServerEvent('qb-gascompany:server:requestMission')
    cb(true)
end)

RegisterNUICallback('managerAction', function(data, cb)
    TriggerServerEvent('qb-gascompany:server:managerAction', data)
    cb(true)
end)

RegisterNetEvent('qb-gascompany:client:panelData', function(payload)
    SendNUIMessage({ action = 'refresh', data = payload })
end)
