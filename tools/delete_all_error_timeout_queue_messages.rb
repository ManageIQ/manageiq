cond = {:state => ["error", "timeout"]}
puts "Deleting #{MiqQueue.where(cond).count} queue messages"

result = MiqQueue.where(cond).delete_all

puts "Done, deleted #{result} rows"
