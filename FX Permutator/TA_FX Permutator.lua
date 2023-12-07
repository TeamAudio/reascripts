-- @description FX Permutator
-- @version 1.3.0
-- @changelog
--   Parallel Chance % feature allows root level FX of run to be run in parallel.
--   FX Containers: New Options menu tab allows you to create FX Container as part of your FX Permutator run with their own unique parameters.
--   New FX Container specific actions in the Tools menu 
--   - Randomize Container Params 
--   - Randomize Container Presets
--   - Shuffle Container FX
--    Additional Logging for plugin load failures
-- @author Tech Audio
-- @provides
--   TA_FX Permutator-5.3.dat
--   TA_FX Permutator-5.4.dat

script_path, script_name = ({reaper.get_action_context()})[2]:match("(.-)([^/\\]+).lua$")
loadfile(script_path .. 'TA_FX Permutator-' .. _VERSION:match('[%d.]+') .. '.dat')()
