
--- вимкнути qb-ambulancejob -----------------------------
local resourceToStop = 'qb-ambulancejob'
local function stopResource(resourceName)
	if GetResourceState(resourceName) == 'started' then
		StopResource(resourceName)
		print(resourceName .. resourceName .. ' was shut down.')
	else
		print(resourceName .. resourceName .. ' did not start, already down.')
	end
end
AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		stopResource(resourceToStop)
	end
end)
----------------------------------------------------------


local QBCore = exports['qb-core']:GetCoreObject()

----- Functions -------------------------------
local function loadAnimDict(dict)
	while (not HasAnimDictLoaded(dict)) do
		RequestAnimDict(dict)
		Wait(5)
	end
end

local function DrawTxt(x, y, width, height, scale, text, r, g, b, a, _)
	if GetConvar('qb_locale', 'en') == 'en' then
		SetTextFont(4)
	else
		SetTextFont(1)
	end
	SetTextProportional(0)
	SetTextScale(scale, scale)
	SetTextColour(r, g, b, a)
	SetTextDropShadow(0, 0, 0, 0, 255)
	SetTextEdge(2, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	BeginTextCommandDisplayText('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(x - width / 2, y - height / 2 + 0.005)
end


----- Events ----------------------------------
RegisterNetEvent('server:SetDeathStatus', function(isDead)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData('isdead', isDead)
	end
end)

RegisterNetEvent('server:SetLaststandStatus', function(bool)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if Player then
		Player.Functions.SetMetaData('inlaststand', bool)
	end
end)

RegisterNetEvent('server:ambulanceAlert', function(text)
	print('2.0 sr.AmbulanseAlert')
	local src = source
	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local players = QBCore.Functions.GetQBPlayers()
	for _, v in pairs(players) do
        if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
            print('2. ser.ambAlert - calling cl:ambulanceAlert')
            TriggerClientEvent('client:ambulanceAlert', v.PlayerData.source, coords, text)
			doctorsFound = true
		else 
			print('2.0 sr.AmbulanseAlert - NO DOCTORS!')
			doctorsFound = false
        end
		
	end
end)

RegisterNetEvent('server:RespawnAtHospital', function(hospitalIndex)
	local src = source
    local Player = QBCore.Functions.GetPlayer(src)
		-- Placing in first bed
	print('4.1. sr.RespAtHosp - calling cl:SendToBed')
	TriggerClientEvent('client:SendToBed', src, 1, Config.Locations['hospital'][hospitalIndex]['beds'][1],
        true)
	print('4.2. sr.RespAtHosp - calling cl:SetBed')
	TriggerClientEvent('client:SetBed', -1, 1, true, hospitalIndex)
	if Config.WipeInventoryOnRespawn then
		Player.Functions.ClearInventory()
		MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?',
			{ json.encode({}), Player.PlayerData.citizenid })
		-- TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error')
	end
end)

RegisterNetEvent('server:LeaveBed', function(id, hospitalIndex)
	print('8.1. server:LeaveBed - calling client:SetBed')
	TriggerClientEvent('client:SetBed', -1, id, false, hospitalIndex)
end)


RegisterNetEvent('InteractSound_SV:PlayOnSource')
AddEventHandler('InteractSound_SV:PlayOnSource', function(soundFile, soundVolume)
	TriggerClientEvent('InteractSound_CL:PlayOnOne', source, soundFile, soundVolume)
end)

RegisterNetEvent('server:resetHungerThirst', function()
	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return end

	Player.Functions.SetMetaData('hunger', 100)
	Player.Functions.SetMetaData('thirst', 100)

	TriggerClientEvent('hud:client:UpdateNeeds', source, 100, 100)
end) 
----- Commands --------------------------------
QBCore.Commands.Add('die', Lang:t('info.kill'), { { name = 'id', help = Lang:t('info.player_id') } }, false,
	function(source, args)
		local src = source
		if args[1] then
			local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
			if Player then
				TriggerClientEvent('hospital:client:KillPlayer', Player.PlayerData.source)
			else
				TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
			end
		else
			TriggerClientEvent('hospital:client:KillPlayer', src)
		end
	end, 'admin')

RegisterCommand('live', function(source)
    local src = source
    TriggerClientEvent('hospital:client:StandUp', src)
	end, 'all')