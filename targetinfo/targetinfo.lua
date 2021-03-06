--[[
* Ashita - Copyright (c) 2014 - 2016 atom0s [atom0s@live.com]
*
* This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
* To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/ or send a letter to
* Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
*
* By using Ashita, you agree to the above license and its terms.
*
*      Attribution - You must give appropriate credit, provide a link to the license and indicate if changes were
*                    made. You must do so in any reasonable manner, but not in any way that suggests the licensor
*                    endorses you or your use.
*
*   Non-Commercial - You may not use the material (Ashita) for commercial purposes.
*
*   No-Derivatives - If you remix, transform, or build upon the material (Ashita), you may not distribute the
*                    modified material. You are, however, allowed to submit the modified works back to the original
*                    Ashita project in attempt to have it added to the original project.
*
* You may not apply legal terms or technological measures that legally restrict others
* from doing anything the license permits.
*
* No warranties are given.
]]--

_addon.author   = 'lejar';
_addon.name     = 'targetinfo';
_addon.version  = '1.0.1';

require 'common'


-- Mapping of ID to level.
local levels = {};
local conditions = {};

-- These are the keys for easy prey, event match, etc.
local valid_types = {
    [0x40]=true,
    [0x41]=true,
    [0x42]=true,
    [0x43]=true,
    [0x44]=true,
    [0x45]=true,
    [0x46]=true,
    [0x47]=true,
    [0x49]=true
    }

-- These are the keys for evasion and defense modifiers.
local valid_conditions = {
    [0xAA]='High Evasion, High Defense',
    [0xAB]='High Evasion',
    [0xAC]='High Evasion, Low Defense',
    [0xAD]='High Defense',
    [0xAE]='',
    [0xAF]='Low Defense',
    [0xB0]='Low Evasion, High Defense',
    [0xB1]='Low Evasion',
    [0xB2]='Low Evasion, Low Defense'
};


----------------------------------------------------------------------------------------------------
-- func: load
-- desc: Event called when the addon is being loaded.
----------------------------------------------------------------------------------------------------
ashita.register_event('load', function()
    imgui.SetNextWindowSize(200, 80, ImGuiSetCond_Always);
end);

----------------------------------------------------------------------------------------------------
-- func: render
-- desc: Called when the addon is rendering.
----------------------------------------------------------------------------------------------------
ashita.register_event('render', function()
    -- Obtain the local player.
    local party = AshitaCore:GetDataManager():GetParty();
    local player = GetPlayerEntity();
    if (player == nil or party == nil) then
        return;
    end

    -- Go through the cached levels and check if the entity is either too far away or dead.
    -- Using the spawn packets to reset entries is unreliable.
    for index, level in pairs(levels) do
        local entity = GetEntity(index);

        if (entity == nil or entity.HealthPercent == 0 or math.sqrt(entity.Distance) > 50) then
            -- Deleting entries in a loop in lua is okay.
            levels[index] = nil;
            conditions[index] = nil;
        end
    end

    -- Get the reference to the target entity.
    local target_index = AshitaCore:GetDataManager():GetTarget():GetTargetIndex();
    local target = GetEntity(target_index);

    -- If there is no target, do not render the window.
    if target == nil then
        return;
    end

    -- Check if the target is another player.
    local is_player = false;
    if (target ~= nil and target.EntityType == EntityType.Player) then
        is_player = true;
    end

    local is_npc = false;
    if (target ~= nil and (bit.band(target.SpawnFlags, EntitySpawnFlags.Npc) ~= 0 or bit.band(target.SpawnFlags, EntitySpawnFlags.Object) ~= 0)) then
        is_npc = true;
    end

    -- Check if the target is our pet.
    local is_pet = false;
    local player = GetPlayerEntity();
    if (player ~= nil) then
        is_pet = target_index == player.PetTargetIndex;
    end

    -- Check if the target is our combat target.
    -- This is done by checking if anyone in our party/aliance is marked
    -- as the mobs claim id.
    local is_combat_target = false;
    if (target.ClaimServerId ~= 0) then
        for x = 0, 17 do
            local memberID = party:GetMemberServerId(x);
            if target.ClaimServerId == memberID then
                is_combat_target = true;
            end
        end
    end

    -- Check if the target is claimed by someone else.
    local is_claimed_by_someone_else = false;
    if (target.ClaimServerId ~= 0 and not is_combat_target) then
        is_claimed_by_someone_else = true;
    end

    -- Initialize the window draw.
    if (imgui.Begin('TargetInfo') == false) then
        imgui.End();
        return;
    end
    
    if target ~= nil then
        local name = target.Name;
        local hpp = target.HealthPercent;
        local mpp = target.ManaPercent;
        local tp = 0;

        if levels[target_index] ~= nil then
            name = name .. string.format(' - Lv. %s', levels[target_index])
        end
        
        -- If the current party member is selected, make it visible.
        if is_player then
            -- Players are white.
            imgui.PushStyleColor(ImGuiCol_Text, 1.0, 1.0, 1.0, 1.0);
        elseif is_npc then
            -- NPCs are greenish.
            imgui.PushStyleColor(ImGuiCol_Text, 0.73, 0.98, 0.73, 1.0);
        elseif is_pet then
            -- Pets are blue.
            imgui.PushStyleColor(ImGuiCol_Text, 0.62, 0.82, 0.81, 1.0);
        elseif is_combat_target then
            -- The combat target is red.
            imgui.PushStyleColor(ImGuiCol_Text, 1.0, 0.5, 0.5, 1.0);
        elseif is_claimed_by_someone_else then
            -- Monsters that are claimed by others are purple.
            imgui.PushStyleColor(ImGuiCol_Text, 1.0, 0.0, 0.70, 1.0);
        else
            -- Monsters are yellowish.
            imgui.PushStyleColor(ImGuiCol_Text, 0.92, 0.92, 0.70, 1.0);
        end

        imgui.Text(name);
        imgui.PopStyleColor(1);
        imgui.Separator();

        -- Draw the labels and progress bars.
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, 1.0, 0.61, 0.61, 0.6);
        imgui.Text('HP:');
        imgui.SameLine();
        imgui.PushStyleColor(ImGuiCol_Text, 1.0, 1.0, 1.0, 1.0);
        imgui.ProgressBar(hpp / 100, -1, 14);
        imgui.PopStyleColor(2);
        
        if conditions[target_index] ~= nil then
            imgui.Text(conditions[target_index]);
        end
    end
    
    imgui.End();
end);


---------------------------------------------------------------------------------------------------
-- func: incoming_packet
-- desc: Called when our addon receives an incoming packet.
---------------------------------------------------------------------------------------------------
ashita.register_event('incoming_packet', function(id, size, data)
    -- Zone Change Packet
    if (id == 0x000A) then
        -- Reset the level data.
        levels = {};
        conditions = {};
        return false;
    end

    -- Message Basic Packet
    if (id == 0x0029) then
        local p = struct.unpack('l', data, 0x0C + 1); -- Monster Level
        local v = struct.unpack('L', data, 0x10 + 1); -- Check Type
        local m = struct.unpack('H', data, 0x18 + 1); -- Defense and Evasion

        -- Obtain the target entity.
        local target = struct.unpack('H', data, 0x16 + 1);
        local entity = GetEntity(target);
        if (entity == nil) then
            return false;
        end

        -- Check that the packet contains all of the information of a check, because
        -- the header ID is used for lots of different messages.
        if (valid_types[v] == nil or valid_conditions[m] == nil) then
            return false;
        end

        -- Determine if we need to put ??? for an NM. 0xF9 means impossible to guage.
        local lvl = '???';
        if (m ~= 0xF9) then
            lvl = tostring(p);
        end
        levels[target] = lvl;
        conditions[target] = valid_conditions[m];

        -- We return false here because we don't want to block the packet from other addons.
        return false;
    end

    return false;
end);