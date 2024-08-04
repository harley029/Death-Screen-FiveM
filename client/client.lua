QBCore = exports['qb-core']:GetCoreObject()

local isDead = false
DoctorsFound = false          -- for the last message
local InLaststand = false
local deathTime = 0
local deadAnimDict = 'dead'
local deadAnim = 'dead_a'
local isInHospitalBed = false
local heart_counter = 0       -- timer at last stand status
local emsNotified = false           -- trigger if emergency is notified
local canLeaveBed = true            -- trigger for leaving the bed
local bedOccupying = nil
local bedObject = nil
local bedOccupyingData = nil
local hospitalLocation = 1
local cam = nil
local hasPlayerLoaded = true  -- for sound playing
local keyWait = true          -- for the last message
local current_weapon = nil
local was_armed = false


local isInHospitalBed = false
local isBleeding = 0
bleedTickTimer, advanceBleedTimer = 0, 0
fadeOutTimer, blackoutTimer = 0, 0
inBedDict = 'anim@gangops@morgue@table@'
inBedAnim = 'body_search'

local getOutDict = 'switch@franklin@bed'
local getOutAnim = 'sleep_getup_rubeyes'

local LaststandTime = 0
local lastStandDict = 'combat@damage@writhe'
local PainkillerIntervallastStandAnim = 'writhe_loop'


----- Functions --------------------------------
RegisterCommand("getweapon", function()
    local weaponName = getPlayerWeaponName()
    print("Current Weapon: " .. weaponName)
end, false)

RegisterCommand("checkweapon", function()
    if doesPlayerHaveWeapon() then
        print("Player has a weapon.")
    else
        print("Player is unarmed.")
    end
end, false)
---
function getPlayerWeaponName()
    local playerPed = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(playerPed)

    for _, weaponName in ipairs(Config.Weapons) do
        if weaponHash == GetHashKey(weaponName) then
            return string.sub(weaponName, 8) -- Remove "WEAPON_" prefix
        end
    end

    return "UNKNOWN"
end

function doesPlayerHaveWeapon()
    local playerPed = PlayerPedId()
    local weaponHash = GetSelectedPedWeapon(playerPed)

    if weaponHash == GetHashKey("WEAPON_UNARMED") then
        return false
    else
        return true
    end
end

local function applyBlurEffect()
    SetTimecycleModifier("hud_def_blur")
    -- SetTimecycleModifierStrength(1.0)
    CreateThread(function()
        local strength = 1.0
        while strength > 0 do
            Citizen.Wait(50)
            strength = strength - 0.025
            SetTimecycleModifierStrength(strength)
        end
    end)
end

local function removeBlurEffectGradually()
    CreateThread(function()
        local strength = 1.0
        while strength > 0 do
            Citizen.Wait(50)
            strength = strength - 0.025
            SetTimecycleModifierStrength(strength)
        end
        ClearTimecycleModifier()
    end)
end

local function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(1)
    end
end

local function LoadAnimation(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(100)
    end
end

local function DrawTxt(x, y, width, height, scale, text, r, g, b, a, _)
    SetTextFont(4)
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

local function ShowLastMessage()
    DoScreenFadeOut(1000)
    while not IsScreenFadedOut() do
        Wait(1)
    end

    TriggerEvent('Sound_cl:PlayOn', 'heart_stop', 0.6)
    keyWait = true
    while keyWait do
        Wait(5)
        DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255)
        if IsScreenFadedOut then DoScreenFadeIn(0) end
        
        DrawTxt(0.91, 1.0, 1.0, 1.5, 0.6, 'Прошло слишком много времени и Вы потеряли сознание.', 255, 255, 255, 255)
        DrawTxt(0.91, 1.0, 1.0, 1.4, 0.6, 'Мимо проезжал полицейский и отвез Вас в реанимацию.', 255, 255, 255, 255)

        if was_armed then
            DrawTxt(0.91, 1.0, 1.0, 1.3, 0.6, Lang:t('info.weapon_remove', {weapon = current_weapon}), 255, 255, 255, 255)
        end
        DrawTxt(0.52, 1.44, 1.0, 1.0, 0.6, Lang:t('info.button_to_survive'), 255, 255, 255, 255)

        if IsControlJustPressed(0, 38) then -- 38 - код клавиши E
            keyWait = false
            current_weapon = nil
            was_armed = false
        end
    end
    
end

function OnDeath()
    if not isDead then
        isDead = true
        print('1.1. onDeath - calling sr:SetDeathStatus') -- logging
        TriggerServerEvent('server:SetDeathStatus', true)
    end
    local player = PlayerPedId()

    while GetEntitySpeed(player) > 0.5 or IsPedRagdoll(player) do
        Wait(10)
    end

    SetEntityInvincible(player, true)
    SetEntityHealth(player, GetEntityMaxHealth(player))
    if IsPedInAnyVehicle(player, false) then
        loadAnimDict('veh@low@front_ps@idle_duck')
        TaskPlayAnim(player, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 1.0, -1, 1, 0, 0, 0, 0)
        Wait(2000)
    else
        loadAnimDict(deadAnimDict)
        TaskPlayAnim(player, deadAnimDict, deadAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
    end
    Wait(2000)
    print('1.2. onDeath - calling sr:ambulanceAlert') -- logging
    TriggerServerEvent('server:ambulanceAlert', Lang:t('info.civ_died'))
    print('1.2.1. onDeath - calling ShowLastMessage') -- logging
    ShowLastMessage()
    print('1.3. onDeath - calling cl:RespawnAtHospital') -- logging
    TriggerEvent('client:RespawnAtHospital')
end

local function SetBedCam()
    isInHospitalBed = true
    canLeaveBed = false
    local player = PlayerPedId()

    DoScreenFadeOut(1000)
    while not IsScreenFadedOut() do
        Wait(100)
    end

    if IsPedDeadOrDying(player) then
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    end

    bedObject = GetClosestObjectOfType(bedOccupyingData.coords.x, bedOccupyingData.coords.y, bedOccupyingData.coords.z,
        1.0, bedOccupyingData.model, false, false, false)
    FreezeEntityPosition(bedObject, true)

    SetEntityCoords(player, bedOccupyingData.coords.x, bedOccupyingData.coords.y, bedOccupyingData.coords.z + 0.02)

    Wait(500)
    FreezeEntityPosition(player, true)

    loadAnimDict(inBedDict)

    TaskPlayAnim(player, inBedDict, inBedAnim, 8.0, 1.0, -1, 1, 0, 0, 0, 0)
    SetEntityHeading(player, bedOccupyingData.coords.w)

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', 1)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 1, true, true)
    AttachCamToPedBone(cam, player, 31085, 0, 1.0, 1.0, true)
    SetCamFov(cam, 90.0)
    local heading = GetEntityHeading(player)
    heading = (heading > 180) and heading - 180 or heading + 180
    SetCamRot(cam, -45.0, 0.0, heading, 2)

    DoScreenFadeIn(1000)
    Wait(1000)
    FreezeEntityPosition(player, true)
end

local function LeaveBed()
    local player = PlayerPedId()

    RequestAnimDict(getOutDict)
    while not HasAnimDictLoaded(getOutDict) do
        Wait(0)
    end

    FreezeEntityPosition(player, false)
    SetEntityInvincible(player, false)
    SetEntityHeading(player, bedOccupyingData.coords.w + 90)
    TaskPlayAnim(player, getOutDict, getOutAnim, 100.0, 1.0, -1, 8, -1, 0, 0, 0)
    Wait(4000)
    ClearPedTasks(player)
    print('7.1. leaveBed - calling sr:LeaveBed') -- logging
    TriggerServerEvent('server:LeaveBed', bedOccupying, hospitalLocation)
    FreezeEntityPosition(bedObject, true)
    RenderScriptCams(0, true, 200, true, true)
    DestroyCam(cam, false)

    bedOccupying = nil
    bedObject = nil
    bedOccupyingData = nil
    isInHospitalBed = false
   
end

local function SetLaststand(bool)
    local ped = PlayerPedId()
    if bool then
        Wait(500)
        while GetEntitySpeed(ped) > 0.5 or IsPedRagdoll(ped) do Wait(10) end
        local pos = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        LaststandTime = Config.ReviveInterval
        
        if IsPedInAnyVehicle(ped) then
            local veh = GetVehiclePedIsIn(ped)
            local vehseats = GetVehicleModelNumberOfSeats(GetHashKey(GetEntityModel(veh)))
            for i = -1, vehseats do
                local occupant = GetPedInVehicleSeat(veh, i)
                if occupant == ped then
                    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
                    SetPedIntoVehicle(ped, veh, i)
                end
            end
        else
            NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
        end

        SetEntityHealth(ped, 150)
        if IsPedInAnyVehicle(ped, false) then
            LoadAnimation('veh@low@front_ps@idle_duck')
            TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 8.0, -1, 1, -1, false, false, false)
        else
            LoadAnimation('combat@damage@writhe')
            TaskPlayAnim(ped, 'combat@damage@writhe', 'writhe_loop', 1.0, 8.0, -1, 1, -1, false, false, false)
        end
        InLaststand = true
        TriggerServerEvent('server:ambulanceAlert', Lang:t('info.civ_down'))
        
        CreateThread(function()
            while InLaststand do
                ped = PlayerPedId()
                local player = PlayerId()
                if heart_counter <4 then heart_counter = heart_counter + 1 end
                if LaststandTime == 20 or LaststandTime == 40 or LaststandTime == 200 or LaststandTime == 100 then
                    DoScreenFadeOut(1000)
                    while not IsScreenFadedOut() do
                        Wait(100)
                    end
                end
                if LaststandTime == 15 or LaststandTime == 35 or LaststandTime == 195 or LaststandTime == 95 then
                    DoScreenFadeIn(1000)
                    Wait(100)
                end
                if LaststandTime - 1 > Config.MinimumRevive then
                    applyBlurEffect()
                    if heart_counter == 4 then
                        TriggerEvent('Sound_cl:PlayOn', 'heart_strong', 0.6)
                        heart_counter = 0
                    end
                    LaststandTime = LaststandTime - 1
                    Config.DeathTime = LaststandTime
                elseif LaststandTime - 1 <= Config.MinimumRevive and LaststandTime - 1 ~= 0 then
                    removeBlurEffectGradually()
                    if heart_counter == 4 then
                        TriggerEvent('Sound_cl:PlayOn', 'heart_strong', 0.6)
                        heart_counter = 0
                    end
                    LaststandTime = LaststandTime - 1
                    Config.DeathTime = LaststandTime
                elseif LaststandTime - 1 <= 0 then
                    SetLaststand(false)
                    deathTime = 0
                    OnDeath()
                end
                Wait(1000)
            end
        end)
    else
        TaskPlayAnim(ped, lastStandDict, 'exit', 1.0, 8.0, -1, 1, -1, false, false, false)
        InLaststand = false
        LaststandTime = 0
    end
    print('SetLastStand() - calling server:SetLaststandStatus')  -- logging
    TriggerServerEvent('server:SetLaststandStatus', bool)
end

local function ResetAll()
    isBleeding = 0
    bleedTickTimer = 0
    ArmInjuryTimer = 0
    fadeOutTimer = 0
    blackoutTimer = 0
    injured = {}

    TriggerServerEvent('server:resetHungerThirst')
end


----- Events -----------------------------------
-- temporary, for testing only
RegisterNetEvent('hospital:client:KillPlayer', function()
    -- SetEntityHealth(PlayerPedId(), 0)  -- tp kill emmediately
    SetLaststand(true)                    -- to set in lastStand status
end)
-- temporary, for testing only
RegisterNetEvent('hospital:client:StandUp', function()
    local player = PlayerPedId()
    local pos = GetEntityCoords(player, true)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    isDead = false
    SetEntityInvincible(player, false)
    SetEntityMaxHealth(player, 200)
    SetEntityHealth(player, 200)
    ClearPedBloodDamage(player)
    SetPlayerSprint(PlayerId(), true)
    TriggerServerEvent('hospital:server:SetDeathStatus', false)
end)
-- set up warning for the emergensy through the server
RegisterNetEvent('client:ambulanceAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1name = GetStreetNameFromHashKey(street1)
    local street2name = GetStreetNameFromHashKey(street2)
    QBCore.Functions.Notify({ text = text, caption = street1name .. ' ' .. street2name }, 'ambulance')
    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)
    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.ems_alert', { text = text })
    SetBlipSprite(blip, 153)
    SetBlipSprite(blip2, 161)
    SetBlipColour(blip, 1)
    SetBlipColour(blip2, 1)
    SetBlipDisplay(blip, 4)
    SetBlipDisplay(blip2, 8)
    SetBlipAlpha(blip, transG)
    SetBlipAlpha(blip2, transG)
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipAsShortRange(blip, false)
    SetBlipAsShortRange(blip2, false)
    PulseBlip(blip2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipText)
    EndTextCommandSetBlipName(blip)
    while transG ~= 0 do
        Wait(180 * 4)
        transG = transG - 1
        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)
        if transG == 0 then
            RemoveBlip(blip)
            return
        end
    end
end)
-- relocate to the hospital
RegisterNetEvent('client:RespawnAtHospital', function()
    local hospitalIndex = 1 -- Default hospital to respawn at
    print('3. cl.RespAtHosp - calling sr:RespawnAtHospital')  -- logging
    TriggerServerEvent('server:RespawnAtHospital', hospitalIndex)
end)
-- to occupy the nearest bed in the hospital
RegisterNetEvent('client:SendToBed', function(id, data, isRevive)
    bedOccupying = id
    bedOccupyingData = data
    print('5.1. cl.SendToBed - calling SetBedCam()')  -- logging
    SetBedCam()
    CreateThread(function()
        Wait(5)
        if isRevive then
            QBCore.Functions.Notify(Lang:t('success.being_helped'), 'success')
            Wait(Config.AIHealTimer * 1000)
            print('5.2. cl.SendToBed - calling cl:Revive')  -- logging
            TriggerEvent('client:Revive')
        else
            canLeaveBed = true
        end
    end)
end)
-- to set the bed status (free/occupayied)
RegisterNetEvent('client:SetBed', function(id, isTaken, hospitalIndex)
    Config.Locations['hospital'][hospitalIndex]['beds'][id].taken = isTaken
    hospitalLocation = hospitalIndex
end)
-- to revive
RegisterNetEvent('client:Revive', function()
    local player = PlayerPedId()

    if isDead or InLaststand then
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
        isDead = false
        SetEntityInvincible(player, false)
        print('6.1. cl.Revive - calling SetLastStand(false)')  -- logging
        SetLaststand(false)
    end

    if isInHospitalBed then
        loadAnimDict(inBedDict)
        TaskPlayAnim(player, inBedDict, inBedAnim, 8.0, 1.0, -1, 1, 0, 0, 0, 0)
        SetEntityInvincible(player, true)
        canLeaveBed = true
    end

    -- TriggerServerEvent('hospital:server:RestoreWeaponDamage')
    SetEntityMaxHealth(player, 200 / 2)
    SetEntityHealth(player, 200 / 2)
    ClearPedBloodDamage(player)
    SetPlayerSprint(PlayerId(), true)
    print('6.2. cl.Revive - calling ResetAll()')  -- logging
    ResetAll()
    ResetPedMovementClipset(player, 0.0)
    print('6.3. cl.Revive - calling hud:server:RelieveStress')  -- logging
    TriggerServerEvent('hud:server:RelieveStress', 100)
    print('6.4. cl.Revive - calling server:SetDeathStatus')  -- logging
    TriggerServerEvent('server:SetDeathStatus', false)
    print('6.5. cl.Revive - calling server:SetLaststandStatus')  -- logging
    TriggerServerEvent('server:SetLaststandStatus', false)
    emsNotified = false
    QBCore.Functions.Notify(Lang:t('info.healthy'))
end)
-- sound playing
RegisterNetEvent('Sound_cl:PlayOn', function(soundFile, soundVolume)
    print('hasPlayerLoaded ', hasPlayerLoaded)  -- logging
    print('playing sound')  -- logging
    if hasPlayerLoaded then
        SendNUIMessage({
            transactionType   = 'playSound',
            transactionFile   = soundFile,
            transactionVolume = soundVolume
        })
    end
end)
-- Waiting for E-key
RegisterNetEvent('wait')


----- Events Handlers ---------------------------
-- on Death
AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim, victimDied = data[1], data[4] 
        if not IsEntityAPed(victim) then return end
        if victimDied and NetworkGetPlayerIndexFromPed(victim) == PlayerId() and IsEntityDead(PlayerPedId()) then
            if not InLaststand then
                SetLaststand(true)
            elseif InLaststand and not isDead then
                deathTime = Config.DeathTime
                SetLaststand(false)
                OnDeath()
            end
        end
    end
end)
-- Waiting for E-key
AddEventHandler('wait', function()
    EnableControlAction(0, 38, true)
    while keyWait do
        Wait(0)
        if IsControlJustPressed(0, 38) then -- 38 - код клавиши E
            keyWait = false
        end
    end
end)


-- commands -------------------------------------
-- temporary, to check last message
RegisterCommand('button', function()
    ShowLastMessage()
end)
-- temporary, to check sound playing
RegisterCommand("sound", function()
    print('calling sound')  -- logging
    TriggerEvent('Sound_cl:PlayOn', 'heart_strong', 0.6)
    -- TriggerServerEvent('InteractSound_SV:PlayOnSource', '111', 0.6)
end)

-- Threads ---------------------------------------
-- leave bed
CreateThread(function()
    while true do
        local sleep = 1000
        if isInHospitalBed and canLeaveBed then
            sleep = 0
            exports['qb-core']:DrawText(Lang:t('text.bed_out'))
            if IsControlJustReleased(0, 38) then
                exports['qb-core']:KeyPressed(38)
                print(' thread LeaveBed - calling LeaveBed()')  -- logging
                LeaveBed()
                exports['qb-core']:HideText()
            end
        end
        Wait(sleep)
    end
end)

-- dying and lastStand time count
CreateThread(function()
    while true do
        local sleep = 1000
        if isDead or InLaststand then
            sleep = 5
            local ped = PlayerPedId()
            if IsPauseMenuActive() then
                SetFrontendActive(false)
            end
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true)
            EnableControlAction(0, 38, true)
            EnableControlAction(0, 0, true)
            EnableControlAction(0, 322, true)
            EnableControlAction(0, 288, true)
            EnableControlAction(0, 213, true)
            EnableControlAction(0, 249, true)
            EnableControlAction(0, 46, true)
            EnableControlAction(0, 47, true)

            if isDead then
                if not isInHospitalBed then
                    if deathTime > 0 then
                        DrawTxt(0.93, 1.44, 1.0, 1.0, 0.6,
                            Lang:t('info.respawn_txt', { deathtime = math.ceil(deathTime) }), 255, 255, 255, 255)
                    else
                        -- отсюда візвать showLastMessage
                        -- DrawTxt(0.865, 1.44, 1.0, 1.0, 0.6,
                        --     Lang:t('info.respawn_revive', { holdtime = hold, cost = Config.BillCost }), 255, 255, 255,
                        --     255)
                    end
                end

                if IsPedInAnyVehicle(ped, false) then
                    loadAnimDict('veh@low@front_ps@idle_duck')
                    if not IsEntityPlayingAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 3) then
                        TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                    end
                else
                    if isInHospitalBed then
                        if not IsEntityPlayingAnim(ped, inBedDict, inBedAnim, 3) then
                            loadAnimDict(inBedDict)
                            TaskPlayAnim(ped, inBedDict, inBedAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    else
                        if not IsEntityPlayingAnim(ped, deadAnimDict, deadAnim, 3) then
                            loadAnimDict(deadAnimDict)
                            TaskPlayAnim(ped, deadAnimDict, deadAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    end
                end

                SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            elseif InLaststand then
                sleep = 5

                if LaststandTime > Config.MinimumRevive and not emsNotified then
                    DrawTxt(0.52, 1.44, 1.0, 1.0, 0.6, Lang:t('info.bleed_out', { time = math.ceil(LaststandTime) }), 255, 255, 255, 255)
                end
                if LaststandTime <= Config.MinimumRevive or emsNotified then
                    DrawTxt(0.52, 1.44, 1.0, 1.0, 0.6, Lang:t('info.bleed_out_help', { time = math.ceil(LaststandTime) }), 255, 255, 255, 255)
                    if not emsNotified then
                        DrawTxt(0.52, 1.40, 1.0, 1.0, 0.6, Lang:t('info.request_help'), 255, 255, 255, 255)
                    else
                        if doctorsFound then
                            DrawTxt(0.52, 1.40, 1.0, 1.0, 0.6, Lang:t('info.help_requested'), 255, 255, 255, 255)
                        else 
                            DrawTxt(0.52, 1.40, 1.0, 1.0, 0.6, Lang:t('info.help_requested_nodoctors'), 255, 255, 255, 255)
                        end
                    end

                    if IsControlJustPressed(0, 47) and not emsNotified then
                        TriggerServerEvent('server:ambulanceAlert', Lang:t('info.civ_down'))
                        emsNotified = true
                        LaststandTime = LaststandTime + Config.EmsRevive
                    end
                end

                if not isEscorted then
                    if IsPedInAnyVehicle(ped, false) then
                        loadAnimDict('veh@low@front_ps@idle_duck')
                        if not IsEntityPlayingAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 3) then
                            TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    else
                        loadAnimDict(lastStandDict)
                        if not IsEntityPlayingAnim(ped, lastStandDict, lastStandAnim, 3) then
                            TaskPlayAnim(ped, lastStandDict, lastStandAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- get current_weapon
CreateThread(function()
    while true do
        Wait(2000)
        if not InLaststand and not isDead then
            current_weapon = getPlayerWeaponName()
            was_armed = doesPlayerHaveWeapon()
        end
    end
end)
    