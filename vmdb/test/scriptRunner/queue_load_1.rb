threshold, count = ARGV
threshold ||= 500
count ||= 1000

sleep_time = 30

puts "\nHit ^C to quit"

while 1 do
  puts "[#{Time.now.utc}] Checking queue size..."
  size = MiqQueue.count(:conditions => "state = 'ready'")
  puts "[#{Time.now.utc}] Queue size is [#{size}]"

  if size < threshold.to_i
    puts "[#{Time.now.utc}] Queuing #{count} messages..."
    count.to_i.times do |c|
      taskid = nil
      taskid = "3" if (c % 3) == 0
      taskid = "6" if (c % 6) == 0
      taskid = "9" if (c % 9) == 0

      MiqQueue.put(
      :class_name  => "MiqQueue",
      :method_name => "dev_null",
      :zone        => nil,
      :task_id     => taskid,
      :args        => [c, "dummy"]
      )
    end

    puts "[#{Time.now.utc}] Queuing #{count} messages... Done"
  end

  puts "[#{Time.now.utc}] Sleeping for [#{sleep_time}] seconds"
  sleep sleep_time
end
