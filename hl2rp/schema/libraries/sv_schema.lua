﻿function SCHEMA:PlayerFootstep(client, _, _, _, volume)
    if client:isRunning() then
        if client:Team() == FACTION_CP then
            client:EmitSound("npc/metropolice/gear" .. math.random(1, 6) .. ".wav", volume * 130)
            return true
        elseif client:Team() == FACTION_OW then
            client:EmitSound("npc/combine_soldier/gear" .. math.random(1, 6) .. ".wav", volume * 100)
            return true
        end
    end
end

function SCHEMA:OnCharCreated(_, character)
    local inventory = character:getInv()
    if inventory then
        if character:getFaction() == FACTION_CITIZEN then
            inventory:add("cid", 1, {
                name = character:getName(),
                id = math.random(10000, 99999)
            })
        elseif self:isCombineFaction(character:getFaction()) then
            inventory:add("radio", 1)
        end
    end
end

function SCHEMA:LoadData()
    self:loadVendingMachines()
    self:loadDispensers()
    self:loadObjectives()
end

function SCHEMA:PostPlayerLoadout(client)
    if client:isCombine() then
        if client:Team() == FACTION_CP then
            for k, _ in ipairs(lia.class.list) do
                if client:getChar():joinClass(k) then break end
            end

            client:SetArmor(50)
        else
            client:SetArmor(100)
        end

        hook.Run("PlayerRankChanged", client)
        client:addDisplay("Local unit protection measures active at " .. client:Armor() .. "%")
        if lia.module.list.scanner and client:isCombineRank(self.scnRanks) then lia.module.list.scanner:createScanner(client, client:getCombineRank() == "CLAW.SCN") end
    end
end

function SCHEMA:CanPlayerViewData(client)
    if client:isCombine() then return true end
end

function SCHEMA:PlayerUseDoor(client, entity)
    local isAdminFaction = client:isStaffOnDuty()
    if client:isCombine() or isAdminFaction then
        local lock = entity.lock or (IsValid(entity:getDoorPartner()) and entity:getDoorPartner().lock)
        if IsValid(lock) then
            if client:KeyDown(IN_SPEED) then
                lock:toggle()
                return false
            elseif client:KeyDown(IN_WALK) and not isAdminFaction then
                lock:detonate(client)
                return false
            end
        elseif not entity:HasSpawnFlags(256) and not entity:HasSpawnFlags(1024) then
            entity:Fire("open", "", 0)
        end
    end
end

function SCHEMA:PlayerSwitchFlashlight(client)
    if lia.module.list.scanner then return end
    if client:isCombine() then return true end
end

function SCHEMA:PlayerRankChanged(client)
    local rankModels = client:Team() == FACTION_CP and self.rankModels or self.owRankModels
    for k, v in pairs(rankModels) do
        if client:isCombineRank(k) then
            local model
            local skin
            if istable(v) then
                model = v[1]
                skin = v[2]
            else
                model = tostring(v)
            end

            if client:getChar() then
                client:getChar():setModel(model)
                if skin then client:getChar():setData("skin", skin) end
            else
                client:SetModel(model)
            end

            client:SetSkin(skin or 0)
            break
        end
    end
end

function SCHEMA:OnCharVarChanged(character, key)
    if key == "name" and IsValid(character:getPlayer()) and character:getPlayer():isCombine() then
        for k, _ in ipairs(lia.class.list) do
            if character:joinClass(k, true) then break end
        end

        hook.Run("PlayerRankChanged", character:getPlayer())
    end
end

local digitsToWords = {
    [0] = "zero",
    [1] = "one",
    [2] = "two",
    [3] = "three",
    [4] = "four",
    [5] = "five",
    [6] = "six",
    [7] = "seven",
    [8] = "eight",
    [9] = "nine"
}

function SCHEMA:GetPlayerDeathSound(client)
    if client:isCombine() then
        local sounds = self.deathSounds[client:Team()] or self.deathSounds[FACTION_CP]
        local digits = client:getDigits()
        local queue = {"npc/overwatch/radiovoice/lostbiosignalforunit.wav"}
        if tonumber(digits) then
            for i = 1, #digits do
                local digit = tonumber(digits:sub(i, i))
                local word = digitsToWords[digit]
                queue[#queue + 1] = "npc/overwatch/radiovoice/" .. word .. ".wav"
            end

            local chance = math.random(1, 7)
            if chance == 2 then
                queue[#queue + 1] = "npc/overwatch/radiovoice/remainingunitscontain.wav"
            elseif chance == 3 then
                queue[#queue + 1] = "npc/overwatch/radiovoice/reinforcementteamscode3.wav"
            end

            queue[#queue + 1] = {table.Random(self.beepSounds[client:Team()] and self.beepSounds[client:Team()].off or self.beepSounds[FACTION_CP].off), nil, 0.25}
            for _, v in player.Iterator() do
                if v:isCombine() then EmitQueuedSounds(v, queue, 2, nil, v == client and 100 or 65) end
            end
        end

        local location = "unknown location"
        if lia.area and client.getArea then
            local area = lia.area.getArea(client:getArea())
            if area then location = area.name or location end
        end

        self:addDisplay("lost bio-signal for protection team unit " .. digits .. " at " .. location, Color(255, 0, 0))
        return table.Random(sounds)
    end
end

function SCHEMA:PlayerHurt(client, _, _, damage)
    if client:isCombine() and damage > 5 then
        local word = "minor"
        if damage >= 75 then
            word = "immense"
        elseif damage >= 50 then
            word = "huge"
        elseif damage >= 25 then
            word = "large"
        end

        client:addDisplay("local unit has sustained " .. word .. " bodily damage" .. (damage >= 25 and ", seek medical attention" or ""), Color(255, 175, 0))
        local delay
        if client:Health() <= 10 then
            delay = 5
        elseif client:Health() <= 25 then
            delay = 10
        elseif client:Health() <= 50 then
            delay = 30
        end

        if delay then client.liaHealthCheck = CurTime() + delay end
    end
end

function SCHEMA:GetPlayerPainSound(client)
    if client:isCombine() then
        local sounds = self.painSounds[client:Team()] or self.painSounds[FACTION_CP]
        return table.Random(sounds)
    end
end

function SCHEMA:PlayerTick(client)
    if client:isCombine() and client:Alive() and (client.liaHealthCheck or 0) < CurTime() then
        local delay = 60
        if client:Health() <= 10 then
            delay = 10
            client:addDisplay("Local unit vital signs are failing, seek medical attention immediately", Color(255, 0, 0))
        elseif client:Health() <= 25 then
            delay = 20
            client:addDisplay("Local unit must seek medical attention immediately", Color(255, 100, 0))
        elseif client:Health() <= 50 then
            delay = 45
            client:addDisplay("Local unit is advised to seek medical attention when possible", Color(255, 175, 0))
        end

        client.liaHealthCheck = CurTime() + delay
    end
end

function SCHEMA:PlayerMessageSend(client, chatType, message, _, receivers)
    if not lia.voice.chatTypes[chatType] then return end
    for _, definition in ipairs(lia.voice.getClass(client)) do
        local sounds, message = lia.voice.getVoiceList(definition.class, message)
        if sounds then
            local volume = 80
            if chatType == "w" then
                volume = 60
            elseif chatType == "y" then
                volume = 150
            end

            if definition.onModify then if definition.onModify(client, sounds, chatType, message) == false then continue end end
            if definition.isGlobal then
                netstream.Start(nil, "voicePlay", sounds, volume)
            else
                netstream.Start(nil, "voicePlay", sounds, volume, client:EntIndex())
                if chatType == "radio" and receivers then
                    for _, v in pairs(receivers) do
                        if receivers == client then continue end
                        netstream.Start(nil, "voicePlay", sounds, volume * 0.5, v:EntIndex())
                    end
                end
            end
            return message
        end
    end
end

function SCHEMA:PlayerStaminaLost(client)
    if client:isCombine() then client:addDisplay("Local unit energy has been exhausted") end
end

function SCHEMA:CanPlayerViewObjectives(client)
    return client:isCombine()
end

function SCHEMA:CanPlayerEditObjectives(client)
    return client:isCombine()
end
