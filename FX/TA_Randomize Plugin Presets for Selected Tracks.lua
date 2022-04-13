-- Tech Audio Randomize the presets of all plugins for selected tracks
local current_selected_track_count = reaper.CountSelectedTracks(0)
for i = 0, current_selected_track_count do
	local found_selected_track = reaper.GetSelectedTrack(0, i)
	if found_selected_track then
		local vst_count = reaper.TrackFX_GetCount(found_selected_track)
		for vstc = 0, vst_count do
			local _, preset_count = reaper.TrackFX_GetPresetIndex(found_selected_track, vstc)
            if preset_count > 1 then
            	reaper.TrackFX_SetPresetByIndex(found_selected_track, vstc, math.random(1,preset_count))
             end
		end
	end
end