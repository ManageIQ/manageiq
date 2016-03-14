total = 0
5.times do
  ping = EvmDatabase.ping
  puts "%.6f ms" % ping
  total += ping
  sleep 1
end
puts
puts "Average: %.6f ms" % (total / 5)
