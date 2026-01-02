--[[
    This is a snippet from my demo shooter game, it basically 
    overrides the dropping and equipping tools that are designated as guns
    it also is responsible for m1 and m2 behavior

	If you still need more clarification please just contact me I am mostly online throughout the day.
	Thanks
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


--Gets the required services
local ViewModelClient=require(ReplicatedStorage.Shared.Services.ViewModelService.ViewModelClient)
local ViewModelSway=require(ReplicatedStorage.Shared.Services.ViewModelService.Utility.ViewModelSway)
local WeaponClass=require(ReplicatedStorage.Shared.Classes.WeaponClass)
local WeaponTypes=require(ReplicatedStorage.Shared.Services.WeaponService.Utility.WeaponTypes)
local WeaponAmmo=require(ReplicatedStorage.Shared.Services.WeaponService.Utility.WeaponAmmo)
local GUIClient=require(ReplicatedStorage.Shared.Services.GUIService.GUIClient)
--[[
	SETTINGS
]]
--settings 
local CREATE_TOUCH_BUTTON=false
local AIMING_SWAY_AMOUNT=0.05
local NOT_AIMING_SWAY_AMOUNT=0.1
--[[
	VARIABLES
]]
-- just the currently loaded animations
local loadedAnimations={}
local loadedSounds={}
--[[
	DROPPING
]]

--[[
	This function just allows you to drop the tool designated as a weapon, now the reason why I did a personal drop function instead of using 
	the one that you get with just roblox is because 
	1.I can set my own keybinds 
	2.I can add other stuff like destroyLoadedAssets 
	3.Because when you drop a tool it actually has no handle reason will be explained below but this function fires an event to WeaponClient that
	will then send a remote request to drop from the server in which the server will create a handle 
]]
function WeaponBehavior.weaponDrop(weapon: WeaponClass.Weapon)
	ContextActionService:BindAction("WeaponDrop",function()	
	
		local player=Players.LocalPlayer::Player
		local character=player.Character::Model
		
		if(weapon.tool) then
			--Just check if the tool attached to the weaponclass is still there
			destroyLoadedAssets()
	
				--Destroy the loaded assets(sfx,animations)
			--Fire the bindable event to commmunicate to WeaponClient,
			ReplicatedStorage.Remotes.WeaponService.WeaponDrop:FireServer(weapon.tool)
		end
		
	end,CREATE_TOUCH_BUTTON,Enum.KeyCode.Backspace)
end

function WeaponBehavior.weaponCantDrop()
	ContextActionService:UnbindAction("WeaponDrop")
end
--[[
	EQUIP/UNEQUIP
]]

--[[
This is a function that will be called from the WeaponClient module, 
the WeaponClient module has an array of all the weapons in the game which is queried from the server when it starts up.
After that when a player picks up a tool that is designated as a weapon only then will it get passed to handleWeaponEquip 

that Weapon Tool has an attribute which is its weaponId(which is generated from httpService) which it agains queries from the server 
if it needs thes stat of the particular weapon

The reason why I did it this way is that setting the stats of a weapon is easier that attaching all the stats of a weapon to attributes of a tool

And the reason why I made a WeaponClass in the first place is so that down the line weapons can have base stats but they can be modified and stats of a weapon 
is solely controlled by the server 
]]

function WeaponBehavior.handleWeaponEquip(weapon: WeaponClass.Weapon)
	--update gui
	GUIClient:updateWeapon(weapon)
	--update viewmodel
	ViewModelClient:equipWeapon(weapon)
	WeaponBehavior.weaponDrop(weapon)
	WeaponBehavior.weaponPrimary(weapon)
	WeaponBehavior.weaponSecondary(weapon)
	--preloadthe assets
	WeaponBehavior.preloadAssets()
	--play sound
	loadedSounds["Equip"]:Play()
	WeaponAmmo:weaponEquipped(weapon)
end

--[[
	This function just detaches all the ContextActionService Bindings so that it doesnt fire multiple times for different weapons
	It also updates the GUI Service, and calls the other functions for unequipping which I will explain below
]]
function WeaponBehavior.handleWeaponUnequip(weapon: WeaponClass.Weapon)
	GUIClient:updateWeapon(nil)
	ViewModelClient:unequipWeapon()
	ViewModelClient:setOffset(CFrame.new())
	WeaponBehavior.weaponCantDrop()
	WeaponBehavior.weaponCantPrimary()
	WeaponBehavior.weaponCantSecondary()
	loadedSounds["Unequip"]:Play()
	destroyLoadedAssets()
	WeaponAmmo:weaponUnequipped(weapon)
end
--[[
	PRIMARY/MOUSE1
]]

--[[
	Ofcourse once you equip the weapon it will now bind the left mouse button to my firing function 
	This firing function also calls the VFX,SFX and animation of the viewmodel bellow, this also fires the client sided weaponAmmo module that tracks your own Ammo
	and updates the GUI
]]
function WeaponBehavior.weaponPrimary(weapon:WeaponClass.Weapon)
	local debounceCooldown=weapon.attackSpeed
	local debouncePrimary=false
	ContextActionService:BindAction("WeaponPrimary",function()
		local player=Players.LocalPlayer::Player
		local character=player.Character::Model
		if(weapon.tool and debouncePrimary==false and WeaponAmmo:ammoLeft()) then
			--check if the tool the weapon is associated with is still there check if cd is off then if the weapon still has ammo left
			debouncePrimary=true
			handlePrimaryAnimation()
			handlePrimarySound()
			handlePrimaryVFX()
			WeaponAmmo:weaponFired()
			ReplicatedStorage.Shared.Events.WeaponService.WeaponFired:Fire(weapon)
			task.delay(debounceCooldown,function()
				debouncePrimary=false
			end,0)
		end
	end,CREATE_TOUCH_BUTTON,Enum.UserInputType.MouseButton1)
end


--[[
	These are just seperate functions for the animations, sounds and vfx
]]
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
--[[
	The vfx is just a part welded to the barrel and my toggleVFX function finds the children of that basepart and enables all particle emitters
]]
function handlePrimaryVFX()
	local viewModel=ViewModelClient:getViewModel()
	local attachment=viewModel:FindFirstChild("VFX"):FindFirstChild("Attachment")::Attachment
	toggleVFX(attachment,true)
	task.delay(0.15,function()
		toggleVFX(attachment,false)
	end,0)
end
--[[
	As I said just enables all particle emitters
]]
function toggleVFX(attachment: Attachment, toggle: boolean)
	for _,vfx in attachment:GetChildren() do
		vfx=vfx::ParticleEmitter
		vfx.Enabled=toggle
	end
end
--[[
	And finally this is the function that unbinds the m1 to the firing function
]]
function WeaponBehavior.weaponCantPrimary()
	ContextActionService:UnbindAction("WeaponPrimary")
end
--[[
	SECONDARY/MOUSE2
]]

--[[
	Moving on, this is the m2 of the weapon that zooms in the camera(actually the viewmodel is just being offset to the aimpart) to the ironsight of the pistol
]]
function WeaponBehavior.weaponSecondary(weapon:WeaponClass.Weapon)
	if(weapon.collisionType==WeaponTypes.CollisionTypes.Ranged) then
		ContextActionService:BindAction("WeaponSecondary",function(_,_,input:InputObject)
			local player=Players.LocalPlayer::Player
			local character=player.Character::Model
			if(weapon.tool) then
				local viewModel=ViewModelClient:getViewModel()
				local viewModelHead=viewModel:FindFirstChild("Head")::BasePart
				local aimPart=viewModel:FindFirstChild("AimPart")::BasePart
				local offset=aimPart.CFrame:ToObjectSpace(viewModelHead.CFrame)
				--this calculates the offset that needs to be applied to the viewmodel to make it look as if you are looking at the ironsight of the pistol
				if(input.UserInputState==Enum.UserInputState.Begin) then
					--Sets the offsets
					ViewModelClient:setOffset(offset)
					--sets the sway (basically lowers it)
					ViewModelSway:setSwayAmount(AIMING_SWAY_AMOUNT)
				elseif(input.UserInputState==Enum.UserInputState.End) then
					--then set back to default after they stop aiming
					ViewModelClient:setOffset(CFrame.new(0,0,0))
					ViewModelSway:setSwayAmount(NOT_AIMING_SWAY_AMOUNT)
				end
			end
		end,CREATE_TOUCH_BUTTON,Enum.UserInputType.MouseButton2)
	end
end
--Just unbinds the contextactionservice if they unequip
function WeaponBehavior.weaponCantSecondary()
	ContextActionService:UnbindAction("WeaponSecondary")
end
--[[
	PRELOAD ANIMATIONS AND SOUNDS FOR WEAPONS
]]


--[[
	Everytime we equip a weapon even before the player fires we want to load the assets to reduce possible delays if we have to load it each time they fire
	Also this makes it so the sound and animation will only be loaded once and the same AnimationTrack will be played incase they fire again
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
--[[
	Preloads the animations in the Viewmodel Folder 
]]
function preloadAnimations(folder: Folder)
	local loadedAnimations={}
	for _, asset in ipairs(folder:GetChildren()) do
		if asset:IsA("Animation") then
			if(asset.Name=="Equip" or asset.Name=="Unequip" or asset.Name=="Idle") then
				continue
			end
			--gets animation controller then animator then the animation track then stores it into the loadedAnimatins
			local animationController=ViewModelClient:getViewModel():FindFirstChild("AnimationController")::AnimationController
			local animator=animationController:FindFirstChild("Animator")::Animator
			local animationTrack=animator:LoadAnimation(asset)
			loadedAnimations[asset.Name]=animationTrack
		end
	end
	return loadedAnimations
end
--[[
Just seperate function that loads the sound and puts into loadedsounds 
]]
function preloadSounds(folder: Folder)
	local loadedSounds={}
	for _, asset in ipairs(folder:GetChildren()) do
		if asset:IsA("Sound") then
			loadedSounds[asset.Name]=asset
		end
	end
	return loadedSounds
end

--[[
	If a player unequips all loadedanimations and sounds are destroyed so they no longer take up memory
]]
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

type WeaponBehavior = typeof(WeaponBehavior)

return WeaponBehavior :: WeaponBehavior

