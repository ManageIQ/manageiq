conf = MiqReplicationWorker.worker_settings.fetch_path(:replication, :destination)
conf = conf.values_at(:host, :port, :username, :password, :database, :adapter)

total = 0
5.times do
  ping = MiqRegionRemote.db_ping(*conf)
  puts "%.6f ms" % ping
  total += ping
  sleep 1
end
puts
puts "Average: %.6f ms" % (total / 5)
