--[[
    This is a snippet from my demo shooter game, it basically 
    overrides the dropping and equipping tools that are designated as guns
    it also is responsible for m1 and m2 behavior
]]
--!strict
local WeaponBehavior = {}
--[[
	DEPENDENCIES
]]
local ContextActionService=game:GetService("ContextActionService")
local ContentProvider=game:GetService("ContentProvider")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")

local ViewModelClient=require(ReplicatedStorage.Shared.Services.ViewModelService.ViewModelClient)
local ViewModelSway=require(ReplicatedStorage.Shared.Services.ViewModelService.Utility.ViewModelSway)
local WeaponClass=require(ReplicatedStorage.Shared.Classes.WeaponClass)
local WeaponTypes=require(ReplicatedStorage.Shared.Services.WeaponService.Utility.WeaponTypes)
local GUIClient=require(ReplicatedStorage.Shared.Services.GUIService.GUIClient)
--[[
	SETTINGS
]]
local CREATE_TOUCH_BUTTON=false
local WEAPON_DROP_DISTANCE=5
local AIMING_SWAY_AMOUNT=0.05
local NOT_AIMING_SWAY_AMOUNT=0.1
--[[
	VARIABLES
]]
local loadedAnimations={}
local loadedSounds={}
--[[
	DROPPING
]]
function WeaponBehavior.weaponDrop()
	ContextActionService:BindAction("WeaponDrop",function()	

		local player=Players.LocalPlayer::Player
		local character=player.Character::Model
		
		local foundWeapon=WeaponBehavior.findWeapon(character)
		if(foundWeapon) then
			destroyLoadedAssets()
			ReplicatedStorage.Remotes.WeaponService.WeaponDrop:FireServer(foundWeapon)
		end
		
	end,CREATE_TOUCH_BUTTON,Enum.KeyCode.Backspace)
end

function WeaponBehavior.weaponCantDrop()
	ContextActionService:UnbindAction("WeaponDrop")
end
--[[
	EQUIP/UNEQUIP
]]
function WeaponBehavior.handleWeaponEquip(weapon: WeaponClass.Weapon)
	GUIClient:updateWeapon(weapon)
	ViewModelClient:equipWeapon(weapon)
	WeaponBehavior.weaponDrop()
	WeaponBehavior.weaponPrimary(weapon)
	WeaponBehavior.weaponSecondary(weapon)
	WeaponBehavior.preloadAssets()
	loadedSounds["Equip"]:Play()
end
function WeaponBehavior.handleWeaponUnequip(weapon: WeaponClass.Weapon)
	GUIClient:updateWeapon(nil)
	ViewModelClient:unequipWeapon()
	ViewModelClient:setOffset(CFrame.new())
	WeaponBehavior.weaponCantDrop()
	WeaponBehavior.weaponCantPrimary()
	WeaponBehavior.weaponCantSecondary()
	loadedSounds["Unequip"]:Play()
	destroyLoadedAssets()
end
--[[
	PRIMARY/MOUSE1
]]
function WeaponBehavior.weaponPrimary(weapon:WeaponClass.Weapon)
	local debounceCooldown=weapon.attackSpeed
	local debouncePrimary=false
	ContextActionService:BindAction("WeaponPrimary",function()
		local player=Players.LocalPlayer::Player
		local character=player.Character::Model
		local foundWeapon=WeaponBehavior.findWeapon(character)
		if(foundWeapon and debouncePrimary==false) then
			debouncePrimary=true
			handlePrimaryAnimation()
			handlePrimarySound()
			handlePrimaryVFX()
			ReplicatedStorage.Shared.Events.WeaponService.WeaponFired:Fire(weapon)
			task.delay(debounceCooldown,function()
				debouncePrimary=false
			end,0)
		end
	end,CREATE_TOUCH_BUTTON,Enum.UserInputType.MouseButton1)
end

function handlePrimaryAnimation()
	local primaryAnim=loadedAnimations["Primary"]::AnimationTrack
	primaryAnim:Play()
end

function handlePrimarySound()
	task.wait(0.2)
	local viewModel=ViewModelClient:getViewModel()
	local primarySound=viewModel:FindFirstChild("Sounds"):FindFirstChild("Primary")::Sound
	primarySound:Play()
end

function handlePrimaryVFX()
	local viewModel=ViewModelClient:getViewModel()
	local attachment=viewModel:FindFirstChild("VFX"):FindFirstChild("Attachment")::Attachment
	toggleVFX(attachment,true)
	task.delay(0.15,function()
		toggleVFX(attachment,false)
	end,0)
end

function toggleVFX(attachment: Attachment, toggle: boolean)
	for _,vfx in attachment:GetChildren() do
		vfx=vfx::ParticleEmitter
		vfx.Enabled=toggle
	end
end

function WeaponBehavior.weaponCantPrimary()
	ContextActionService:UnbindAction("WeaponPrimary")
end
--[[
	SECONDARY/MOUSE2
]]
function WeaponBehavior.weaponSecondary(weapon:WeaponClass.Weapon)
	if(weapon.weaponType==WeaponTypes.Ranged) then
		ContextActionService:BindAction("WeaponSecondary",function(_,_,input:InputObject)
			local player=Players.LocalPlayer::Player
			local character=player.Character::Model
			local foundWeapon=WeaponBehavior.findWeapon(character)
			if(foundWeapon) then
				local viewModel=ViewModelClient:getViewModel()
				local viewModelHead=viewModel:FindFirstChild("Head")::BasePart
				local aimPart=viewModel:FindFirstChild("AimPart")::BasePart
				local offset=aimPart.CFrame:ToObjectSpace(viewModelHead.CFrame)
				if(input.UserInputState==Enum.UserInputState.Begin) then
					ViewModelClient:setOffset(offset)
					ViewModelSway:setSwayAmount(AIMING_SWAY_AMOUNT)
				elseif(input.UserInputState==Enum.UserInputState.End) then
					ViewModelClient:setOffset(CFrame.new(0,0,0))
					ViewModelSway:setSwayAmount(NOT_AIMING_SWAY_AMOUNT)
				end
			end
		end,CREATE_TOUCH_BUTTON,Enum.UserInputType.MouseButton2)
	end
end

function WeaponBehavior.weaponCantSecondary()
	ContextActionService:UnbindAction("WeaponSecondary")
end
--[[
	PRELOAD ANIMATIONS AND SOUNDS FOR WEAPONS
]]

function WeaponBehavior.preloadAssets()
	
	local viewModel=ViewModelClient:getViewModel()
	local animations=viewModel:FindFirstChild("Animations") :: Folder
	local sounds=viewModel:FindFirstChild("Sounds") :: Folder
	if(animations and sounds) then	
		loadedAnimations=preloadAnimations(animations)
		loadedSounds=preloadSounds(sounds)
	end
end
function preloadAnimations(folder: Folder)
	local loadedAnimations={}
	for _, asset in ipairs(folder:GetChildren()) do
		if asset:IsA("Animation") then
			if(asset.Name=="Equip" or asset.Name=="Unequip" or asset.Name=="Idle") then
				continue
			end
			local animationController=ViewModelClient:getViewModel():FindFirstChild("AnimationController")::AnimationController
			local animator=animationController:FindFirstChild("Animator")::Animator
			local animationTrack=animator:LoadAnimation(asset)
			loadedAnimations[asset.Name]=animationTrack
		end
	end
	return loadedAnimations
end
function preloadSounds(folder: Folder)
	local loadedSounds={}
	for _, asset in ipairs(folder:GetChildren()) do
		if asset:IsA("Sound") then
			loadedSounds[asset.Name]=asset
		end
	end
	return loadedSounds
end
function destroyLoadedAssets()
	for _, asset in pairs(loadedAnimations) do
		asset=asset::AnimationTrack
		asset:Stop()
		asset:Destroy()
	end
	for _, asset in pairs(loadedSounds) do
		asset=asset::Sound
		asset:Stop()
		asset:Destroy()
	end
end
--[[
	UTILITY
]]
function WeaponBehavior.findWeapon(character: Model):Tool | nil
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

type WeaponBehavior = typeof(WeaponBehavior)

return WeaponBehavior :: WeaponBehavior
