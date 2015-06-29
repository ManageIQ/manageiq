require 'sync'
require_relative '../SyncDebug'

class SyncDebug
  include Sync_m
  include SyncDebug_m
end

SyncDebug.on_lock_request do |li|
  puts "Requesting lock: #{li[:lock].lock_name}, from_mode = #{li[:lock].sync_mode}, to_mode = #{li[:mode]} [#{li[:call_stack][0]}]"
end

sd = SyncDebug.new
sd.lock_name = "TestLock"

sd.on_lock_acquire do |li|
  puts "Acquired lock: #{li[:lock].lock_name}, acquired_mode = #{li[:lock].sync_mode}, requested_mode = #{li[:mode]} [#{li[:call_stack][0]}]"
end

sd.on_unlock_request do |li|
  puts "Releasing lock: #{li[:lock].lock_name}, pre-release_mode = #{li[:lock].sync_mode}, [#{li[:call_stack][0]}]"
end
sd.on_unlock do |li|
  puts "Released lock: #{li[:lock].lock_name}, post-release_mode = #{li[:lock].sync_mode}, [#{li[:call_stack][0]}]"
end

sd.on_try_lock_request do |li|
  puts "Requesting lock: #{li[:lock].lock_name}, from_mode = #{li[:lock].sync_mode}, to_mode = #{li[:mode]} [#{li[:call_stack][0]}]"
end
sd.on_try_lock_return do |li, rv|
  puts "#{li[:lock].lock_name}, mode = #{li[:mode]}: acquired = #{rv} [#{li[:call_stack][0]}]"
end

# exit

sd.synchronize(:EX) do
  puts "    Running protected code 1 (synchronize)..."
end

puts

sd.sync_lock(:EX)
puts "    Running protected code 2 (sync_lock/sync_unlock)..."
sd.sync_unlock

puts

sd.lock(:EX)
puts "    Running protected code 3 (lock/unlock)..."
sd.unlock


puts

have_lock = sd.sync_try_lock(:EX)
puts "    Running protected code 4 (sync_try_lock/sync_unlock)..."
sd.sync_unlock if have_lock

puts

have_lock = sd.try_lock(:EX)
puts "    Running protected code 5 (try_lock/unlock)..."
sd.unlock if have_lock

puts
puts "Nesting:"
puts

sd.synchronize(:SH) do # LEVEL 1
  puts "    Running protected code LEVEL 1A..."
  sd.synchronize(:EX) do # LEVEL 2 - promote to exclusive lock
    puts "        Running protected code LEVEL 2A..."
    sd.synchronize(:SH) do # LEVEL 3 - back to shared after exclusive lock
      puts "            Running protected code LEVEL 3A..."
      sd.synchronize(:EX) do # LEVEL 4 - one more exclusive
        puts "                Running protected code LEVEL 4..."
      end
      puts "            Running protected code LEVEL 3B..."
    end
    puts "        Running protected code LEVEL 2B..."
  end
  puts "    Running protected code LEVEL 1B..."
end
