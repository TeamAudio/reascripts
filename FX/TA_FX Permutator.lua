-- @description FX Permutator
-- @version 1.3.1
-- @changelog
--   General UI improvements
--   Selected FX filter
--   Activation fix for Windows
-- @author Tech Audio
-- @provides
--   fxperm/TA_FX Permutator-5.3.dat
--   fxperm/TA_FX Permutator-5.4.dat

script_path, script_name = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
loadfile(script_path .. 'fxperm/TA_FX Permutator-' .. _VERSION:match('[%d.]+') .. '.dat')()
