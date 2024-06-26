﻿AddCSLuaFile()
SWEP.PrintName = "Stunstick"
SWEP.Slot = 1
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
SWEP.Category = "HL2 RP"
SWEP.Author = "@liliaplayer > Discord"
SWEP.Instructions = "Primary Fire: [RAISED] Strike\nALT + Primary Fire: [RAISED] Toggle stun\nSecondary Fire: Push/Knock"
SWEP.Purpose = "Hitting things and knocking on doors."
SWEP.Drop = false
SWEP.HoldType = "melee"
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.ViewModelFOV = 47
SWEP.ViewModelFlip = false
SWEP.AnimPrefix = "melee"
SWEP.ViewTranslation = 4
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""
SWEP.Primary.Damage = 7.5
SWEP.Primary.Delay = 0.7
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""
SWEP.ViewModel = Model("models/weapons/c_stunstick.mdl")
SWEP.WorldModel = Model("models/weapons/w_stunbaton.mdl")
SWEP.UseHands = true
SWEP.LowerAngles = Angle(15, -10, -20)
SWEP.FireWhenLowered = true
function SWEP:SetupDataTables()
    self:NetworkVar("Bool", 0, "Activated")
end

function SWEP:Precache()
    util.PrecacheSound("weapons/stunstick/stunstick_swing1.wav")
    util.PrecacheSound("weapons/stunstick/stunstick_swing2.wav")
    util.PrecacheSound("weapons/stunstick/stunstick_impact1.wav")
    util.PrecacheSound("weapons/stunstick/stunstick_impact2.wav")
    util.PrecacheSound("weapons/stunstick/spark1.wav")
    util.PrecacheSound("weapons/stunstick/spark2.wav")
    util.PrecacheSound("weapons/stunstick/spark3.wav")
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    if not owner:isWepRaised() then return end
    if owner:KeyDown(IN_WALK) then
        if SERVER then
            self:SetActivated(not self:GetActivated())
            local sequence = "deactivatebaton"
            if self:GetActivated() then
                owner:EmitSound("weapons/stunstick/spark3.wav", 100, math.random(90, 110))
                sequence = "activatebaton"
            else
                owner:EmitSound("weapons/stunstick/spark" .. math.random(1, 2) .. ".wav", 100, math.random(90, 110))
            end

            local model = string.lower(owner:GetModel())
            if lia.anim.getModelClass(model) == "metrocop" then owner:forceSequence(sequence, nil, nil, true) end
        end
        return
    end

    self:EmitSound("weapons/stunstick/stunstick_swing" .. math.random(1, 2) .. ".wav", 70)
    self:SendWeaponAnim(ACT_VM_HITCENTER)
    local damage = self.Primary.Damage
    if self:GetActivated() then damage = 5 end
    owner:SetAnimation(PLAYER_ATTACK1)
    owner:ViewPunch(Angle(1, 0, 0.125))
    owner:LagCompensation(true)
    local data = {}
    data.start = owner:GetShootPos()
    data.endpos = data.start + owner:GetAimVector() * 72
    data.filter = owner
    local trace = util.TraceLine(data)
    owner:LagCompensation(false)
    if SERVER and trace.Hit then
        if self:GetActivated() then
            local effect = EffectData()
            effect:SetStart(trace.HitPos)
            effect:SetNormal(trace.HitNormal)
            effect:SetOrigin(trace.HitPos)
            util.Effect("StunstickImpact", effect, true, true)
        end

        owner:EmitSound("weapons/stunstick/stunstick_impact" .. math.random(1, 2) .. ".wav")
        local entity = trace.Entity
        if IsValid(entity) then
            if entity:IsPlayer() then
                if self:GetActivated() then
                    entity.liaStuns = (entity.liaStuns or 0) + 1
                    timer.Simple(10, function() entity.liaStuns = math.max(entity.liaStuns - 1, 0) end)
                end

                entity:ViewPunch(Angle(-20, math.random(-15, 15), math.random(-10, 10)))
                if self:GetActivated() and entity.liaStuns > (hook.Run("PlayerGetStunThreshold", entity, owner) or 3) then
                    entity:setRagdolled(true, 60)
                    entity.liaStuns = 0
                    return
                end
            elseif entity:IsRagdoll() then
                if self:GetActivated() then
                    damage = 2
                else
                    damage = 10
                end
            end

            local damageInfo = DamageInfo()
            damageInfo:SetAttacker(owner)
            damageInfo:SetInflictor(self)
            damageInfo:SetDamage(damage)
            damageInfo:SetDamageType(DMG_CLUB)
            damageInfo:SetDamagePosition(trace.HitPos)
            damageInfo:SetDamageForce(owner:GetAimVector() * 10000)
            entity:DispatchTraceAttack(damageInfo, data.start, data.endpos)
        end
    end
end

function SWEP:OnLowered()
    self:SetActivated(false)
end

function SWEP:Holster()
    self:OnLowered()
    return true
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    owner:LagCompensation(true)
    local data = {}
    data.start = owner:GetShootPos()
    data.endpos = data.start + owner:GetAimVector() * 72
    data.filter = owner
    data.mins = Vector(-8, -8, -30)
    data.maxs = Vector(8, 8, 10)
    local trace = util.TraceHull(data)
    local entity = trace.Entity
    owner:LagCompensation(false)
    if SERVER and IsValid(entity) then
        local pushed
        if entity:isDoor() then
            if hook.Run("PlayerCanKnock", owner, entity) == false then return end
            owner:ViewPunch(Angle(-1.3, 1.8, 0))
            owner:EmitSound("d1_trainstation_03.breakin_doorknock", 125)
            owner:SetAnimation(PLAYER_ATTACK1)
            self:SetNextSecondaryFire(CurTime() + 0.3)
            self:SetNextPrimaryFire(CurTime() + 1)
        elseif entity:IsPlayer() then
            local direction = owner:GetAimVector() * (300 + (owner:getChar():getAttrib("str", 0) * 3))
            direction.z = 0
            entity:SetVelocity(direction)
            pushed = true
        else
            local physObj = entity:GetPhysicsObject()
            if IsValid(physObj) then physObj:SetVelocity(owner:GetAimVector() * 180) end
            pushed = true
        end

        if pushed then
            self:SetNextSecondaryFire(CurTime() + 1.5)
            self:SetNextPrimaryFire(CurTime() + 1.5)
            owner:EmitSound("weapons/crossbow/hitbod" .. math.random(1, 2) .. ".wav")
            local model = string.lower(owner:GetModel())
            if lia.anim.getModelClass(model) == "metrocop" then owner:forceSequence("pushplayer") end
        end
    end
end

local STUNSTICK_GLOW_MATERIAL = Material("effects/stunstick")
local STUNSTICK_GLOW_MATERIAL2 = Material("effects/blueflare1")
local STUNSTICK_GLOW_MATERIAL_NOZ = Material("sprites/light_glow02_add_noz")
local color_glow = Color(128, 128, 128)
function SWEP:DrawWorldModel()
    self:DrawModel()
    if self:GetActivated() then
        local size = math.Rand(4.0, 6.0)
        local glow = math.Rand(0.6, 0.8) * 255
        local color = Color(glow, glow, glow)
        local attachment = self:GetAttachment(1)
        if attachment then
            local position = attachment.Pos
            render.SetMaterial(STUNSTICK_GLOW_MATERIAL2)
            render.DrawSprite(position, size * 2, size * 2, color)
            render.SetMaterial(STUNSTICK_GLOW_MATERIAL)
            render.DrawSprite(position, size, size + 3, color_glow)
        end
    end
end

local NUM_BEAM_ATTACHEMENTS = 9
local BEAM_ATTACH_CORE_NAME = "sparkrear"
function SWEP:PostDrawViewModel()
    if not self:GetActivated() then return end
    local viewModel = LocalPlayer():GetViewModel()
    if not IsValid(viewModel) then return end
    cam.Start3D(EyePos(), EyeAngles())
    local size = math.Rand(3.0, 4.0)
    local color = Color(255, 255, 255, 50 + math.sin(RealTime() * 2) * 20)
    STUNSTICK_GLOW_MATERIAL_NOZ:SetFloat("$alpha", color.a / 255)
    render.SetMaterial(STUNSTICK_GLOW_MATERIAL_NOZ)
    local attachment = viewModel:GetAttachment(viewModel:LookupAttachment(BEAM_ATTACH_CORE_NAME))
    if attachment then render.DrawSprite(attachment.Pos, size * 10, size * 15, color) end
    for i = 1, NUM_BEAM_ATTACHEMENTS do
        local attachment = viewModel:GetAttachment(viewModel:LookupAttachment("spark" .. i .. "a"))
        size = math.Rand(2.5, 5.0)
        if attachment and attachment.Pos then render.DrawSprite(attachment.Pos, size, size, color) end
        local attachment = viewModel:GetAttachment(viewModel:LookupAttachment("spark" .. i .. "b"))
        size = math.Rand(2.5, 5.0)
        if attachment and attachment.Pos then render.DrawSprite(attachment.Pos, size, size, color) end
    end

    cam.End3D()
end
