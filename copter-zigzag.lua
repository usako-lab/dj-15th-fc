local copter_mode_guided = 4
local copter_mode_loiter = 5
local copter_mode_zigzag = 24

local RC1 = rc:get_channel(1)
local RC2 = rc:get_channel(2)
local RC3 = rc:get_channel(3)

local rc_trim = 1500
local rc_high = 2000
local rc_low  = 1000

local takeoff_alt = 10

local stage = 0
local prev_loc = Location()
local cnt = 0

param:set_and_save('RC7_OPTION', 61)
param:set_and_save('RC8_OPTION', 83)
param:set_and_save('ZIGZ_AUTO_ENABLE', 1)
param:set_and_save('ZIGZ_LINE_NUM', -1)

function show_vector3f(vec, msg)
  if vec then
    gcs:send_text(0, msg .. " x=" .. tostring(vec:x()) .. " y=" .. tostring(vec:y()) .. " z=" .. tostring(vec:z()))
  else
    gcs:send_text(0, msg .. " is nil")
  end
end

function show_location(loc, msg)
  if loc then
    gcs:send_text(0, msg .. " alt=" .. tostring(loc:alt()) .. " lng=" .. tostring(loc:lng()) .. " lat=" .. tostring(loc:lat()))
  else
    gcs:send_text(0, msg .. " is nil")
  end
end

function goto_target_pos(x, y, z)
  gcs:send_text(0, "goto_target_pos x=" .. tostring(x) .. " y=" .. tostring(y) .. " z=" .. tostring(z))
  cur_mode = vehicle:get_mode()
  if cur_mode == copter_mode_guided then
    local pos = Vector3f()
    pos:x(x)
    pos:y(y)
    if (z ~= 0) then
      pos:z(-z)
    end
    vehicle:set_target_pos_NED(pos, false, 0, false, 0, false, false)
  else
    gcs:send_text(0, "goto_target_pos, unknown")
  end
  gcs:send_text(0, "goto_target_pos")
  return true
end

function reached_to_pos(x, y, z)
  local cur_loc = ahrs:get_location()
  if prev_loc and cur_loc then
    local distance = prev_loc:get_distance_NED(cur_loc)
    show_location(prev_loc, "previous")
    show_location(cur_loc, "current")
    show_vector3f(distance, "distance")
    gcs:send_text(0, "reached_to_pos x=" .. tostring(x) .. " y=" .. tostring(y) .. " z=" .. tostring(z))
    if distance then
      if (math.abs(x-distance:x()) < 1 and math.abs(y-distance:y()) < 1 and math.abs(z+distance:z()) < 1) then
        prev_loc = ahrs:get_location()
        gcs:send_text(0, "reached_to_pos reached")
        return true
      end
      gcs:send_text(0, "reached_to_pos unreached")
    end
  end
  return false
end

function reset_zigzag_wp()
  local aux_switch = rc:find_channel_for_option(61)
  if aux_switch then
    aux_switch:set_override(1500)
  end
end

function save_zigzag_wp(sw)
  cur_mode = vehicle:get_mode()
  if cur_mode ~= copter_mode_zigzag then
    if (not vehicle:set_mode(copter_mode_zigzag)) then
      gcs:send_text(0, "save_zigzag_wp, failed to zigzag")
      return false
    end
  end
  local aux_switch = rc:find_channel_for_option(61)
  if aux_switch then
    local sw_pos = aux_switch:get_aux_switch_pos()
    gcs:send_text(0, "sw_pos=" .. tostring(sw_pos))
    if (sw == 0) then
      aux_switch:set_override(900)
      gcs:send_text(0, "save_zigzag_wp saved A")
      return true
    elseif (sw == 1) then
      aux_switch:set_override(2000)
      gcs:send_text(0, "save_zigzag_wp saved B")
      return true
    end
  end
  return false
end

function run_zigzag_wp()
  local aux_switch = rc:find_channel_for_option(83)
  if aux_switch then
    aux_switch:set_override(2000)
  end
end

function update()
  gcs:send_text(0, "RC1=" .. tostring(rc:get_pwm(1)) .. " RC2=" .. tostring(rc:get_pwm(2)) .. " RC3=" .. tostring(rc:get_pwm(3)) .. " RC4=" .. tostring(rc:get_pwm(4)))

  if not arming:is_armed() then
    if (rc:get_pwm(3) ~= rc_low) then
      gcs:send_text(0, "set_override, rc_low")
      RC3:set_override(rc_low)
    end
    return update, 1000
  end
  gcs:send_text(0, "armed")

  cur_mode = vehicle:get_mode()

  if stage == 0 then
    if cur_mode ~= copter_mode_guided then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    gcs:send_text(0, "guided")
    if vehicle:start_takeoff(takeoff_alt) then
      gcs:send_text(0, "takeoff")
      stage = stage + 1
    end
  elseif stage == 1 then
    if cur_mode ~= copter_mode_guided then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    RC3:set_override(rc_trim)
    local home = ahrs:get_home()
    local cur_loc = ahrs:get_location()
    if home and cur_loc then
      local vec = home:get_distance_NED(cur_loc)
      gcs:send_text(0, "alt=" .. tostring(math.floor(-vec:z())))
      if (math.abs(takeoff_alt + vec:z()) < 1) then
        stage = stage + 1
      end
    end
  elseif stage == 2 then
    if cur_mode ~= copter_mode_guided then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    RC3:set_override(rc_trim)
    gcs:send_text(0, "goto zigzag wp 1")
    prev_loc = ahrs:get_location()
    goto_target_pos(20, 30, takeoff_alt)
    stage = stage + 1
  elseif stage == 3 then
    if cur_mode ~= copter_mode_guided then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    RC3:set_override(rc_trim)
    gcs:send_text(0, "reach zigzag wp 1")
    if reached_to_pos(20, 30, 0) then
      stage = stage + 1
    end
  elseif stage == 4 then
    if cur_mode ~= copter_mode_guided then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    RC3:set_override(rc_trim)
    gcs:send_text(0, "save zigzag wp 1")
    if (vehicle:set_mode(copter_mode_zigzag)) then
      if save_zigzag_wp(1) then
        stage = stage + 1
      end
    end
  elseif stage == 5 then
    if cur_mode ~= copter_mode_zigzag then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    RC3:set_override(rc_trim)
    gcs:send_text(0, "goto zigzag wp 2")
    reset_zigzag_wp()
    RC1:set_override(rc_high)
    RC2:set_override(rc_high)
    stage = stage + 1
  elseif stage == 6 then
    if cur_mode ~= copter_mode_zigzag then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    reset_zigzag_wp()
    RC3:set_override(rc_trim)
    gcs:send_text(0, "reach zigzag wp 2")
    if cnt < 5 then
      cnt = cnt + 1
    else
      stage = stage + 1
    end
  elseif stage == 7 then
    if cur_mode ~= copter_mode_zigzag then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    RC3:set_override(rc_trim)
    gcs:send_text(0, "save zigzag wp 2")
    if save_zigzag_wp(0) then
      stage = stage + 1
    end
  elseif stage == 8 then
    if cur_mode ~= copter_mode_zigzag then
      gcs:send_text(0, "invalid stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
      return
    end
    RC3:set_override(rc_trim)
    gcs:send_text(0, "run zigzag wp")
    run_zigzag_wp()
  else
    gcs:send_text(0, "stage=" .. tostring(stage) .. " mode=" .. tostring(cur_mode))
    RC3:set_override(rc_trim)
  end
  return update, 1000
end

return update()

