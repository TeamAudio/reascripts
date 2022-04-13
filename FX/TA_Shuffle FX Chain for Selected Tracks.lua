-- Tech Audio Shuffle FX Positions for Selected Tracks
function is_matching_table(t1,t2)
	return table.concat(t1) == table.concat(t2)
end

function shuffle(tbl)
	local t ={}
	for i = 1 ,#tbl do
      table.insert(t,tbl[i])
    end
	for j = #t, 2, -1 do
		local k = math.random(j)
		t[j], t[k] = t[k], t[j]
    end
    if is_matching_table(tbl, t) then
    	t = shuffle(tbl)
    end
    return t
end

local current_selected_track_count = reaper.CountSelectedTracks(0)
for i = 0, current_selected_track_count do
	local found_selected_track = reaper.GetSelectedTrack(0, i)
	if found_selected_track then
        local vst_count = reaper.TrackFX_GetCount(found_selected_track)
        if vst_count > 1 then
        	local fx_indexes ={}
	    	for vi = 0,vst_count-1 do
	            table.insert(fx_indexes,vi)
	        end
           --everyday i'm shufflin
           local shuffled_indexes = shuffle(fx_indexes)
           for s_i =1 ,#fx_indexes-1 do
           		reaper.TrackFX_CopyToTrack(found_selected_track, fx_indexes[s_i], found_selected_track, shuffled_indexes[s_i], true)
           end	
        end
	end
end

