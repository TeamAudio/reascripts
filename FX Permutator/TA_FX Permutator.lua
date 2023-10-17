-- @description FX Permutator
-- @version 1.2.0
-- @changelog
--   REAPER 7 support
-- @author Tech Audio
-- @provides
--   TA_FX Permutator-5.3.dat
--   TA_FX Permutator-5.4.dat

script_path, script_name = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
loadfile(script_path .. 'TA_FX Permutator-' .. _VERSION:match('[%d.]+') .. '.dat')()
