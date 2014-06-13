cond = {:state => ["error", "timeout"]}
puts "Deleting #{MiqQueue.count(:conditions =>  cond)} queue messages"

result = MiqQueue.delete_all(cond)

puts "Done, deleted #{result} rows"
