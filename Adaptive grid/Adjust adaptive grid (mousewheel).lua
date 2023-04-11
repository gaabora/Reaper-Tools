--[[
  @author Ilias-Timon Poulakis (FeedTheCat)
  @license MIT
  @noindex
  @about Use the mousewheel to go through adaptive grid sizes
]]
local extname = 'FTC.AdaptiveGrid'
local _, file, sec, cmd, _, _, val = reaper.get_action_context()
local path = file:match('^(.+)[\\/]')

function print(msg) reaper.ShowConsoleMsg(tostring(msg) .. '\n') end

function ConcatPath(...) return table.concat({...}, package.config:sub(1, 1)) end

function GetGridMultiplier()
    return tonumber(reaper.GetExtState(extname, 'main_mult')) or 0
end

function SetGridMultiplier(multiplier)
    reaper.SetExtState(extname, 'main_mult', multiplier, true)
end

function GetMIDIGridMultiplier()
    return tonumber(reaper.GetExtState(extname, 'midi_mult')) or 0
end

function SetMIDIGridMultiplier(multiplier)
    reaper.SetExtState(extname, 'midi_mult', multiplier, true)
end

function RunAdaptScript(is_midi)
    local script_path = ConcatPath(path, 'Adapt grid to zoom level.lua')

    if is_midi then
        local hwnd = reaper.MIDIEditor_GetActive()
        if hwnd then
            _G.mode = 2
            dofile(script_path)
        end
    else
        _G.mode = 1
        dofile(script_path)
    end
end

function UpdateToolbarToggleStates(section, multiplier)
    local entries = reaper.GetExtState(extname, 'toolbar_entries')
    local updated_entries = ''
    for entry in entries:gmatch('(.-);') do
        local pattern = '(%d+) (.-) (%-?%d+)'
        local entry_sec, entry_cmd_name, entry_mult = entry:match(pattern)
        entry_sec = tonumber(entry_sec)
        entry_mult = tonumber(entry_mult)
        local entry_cmd = reaper.NamedCommandLookup('_' .. entry_cmd_name)
        if section == entry_sec and entry_cmd > 0 then
            local state = entry_mult == multiplier and 1 or 0
            if entry_mult == 1000 and multiplier ~= 0 then state = 1 end
            reaper.SetToggleCommandState(entry_sec, entry_cmd, state)
            reaper.RefreshToolbar2(entry_sec, entry_cmd)
            updated_entries = updated_entries .. entry .. ';'
        elseif section ~= entry_sec then
            updated_entries = updated_entries .. entry .. ';'
        end
    end
    if updated_entries ~= entries then
        reaper.SetExtState(extname, 'toolbar_entries', updated_entries, true)
    end
end

reaper.Undo_BeginBlock()

local GetMultiplier = GetGridMultiplier
local SetMultiplier = SetGridMultiplier

if sec == 32060 then
    GetMultiplier = GetMIDIGridMultiplier
    SetMultiplier = SetMIDIGridMultiplier
end

local mult = GetMultiplier()

-- Treat custom adaptive grid size like medium size
if mult == -1 then mult = 3 end

if mult > 0 then
    -- Change adaptive grid size
    mult = mult + (val < 0 and 1 or -1)
    mult = math.min(5, math.max(1, mult))
    SetMultiplier(mult)
    RunAdaptScript(sec == 32060)
    UpdateToolbarToggleStates(sec, mult)
else
    -- Change fixed grid size
    if sec == 32060 then
        local hwnd = reaper.MIDIEditor_GetActive()
        local take = reaper.MIDIEditor_GetTake(hwnd)
        if reaper.ValidatePtr(take, 'MediaItem_Take*') then
            local grid_div = reaper.MIDI_GetGrid(take) / 4
            grid_div = val < 0 and grid_div * 2 or grid_div / 2
            reaper.SetMIDIEditorGrid(0, grid_div)
        end
    else
        local _, grid_div = reaper.GetSetProjectGrid(0, 0)
        grid_div = val < 0 and grid_div * 2 or grid_div / 2
        reaper.SetProjectGrid(0, grid_div)
    end
end

reaper.Undo_EndBlock('Adjust grid', -1)
