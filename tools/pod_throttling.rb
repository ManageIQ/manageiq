#!/usr/bin/env ruby

# This is only useful for pods in determining cpu throttling

# Some useful links:
# /sys/fs/cgroup/* information: https://engineering.squarespace.com/blog/2017/understanding-linux-container-scheduling
# Looking at cpu.stat throttling to find a kernel bug:
#   part 1) https://medium.com/indeed-engineering/unthrottled-fixing-cpu-limits-in-the-cloud-a0995ede8e89
#   part 2) https://medium.com/indeed-engineering/unthrottled-how-a-valid-fix-becomes-a-regression-f61eabb2fbd9
# Example bash script checking throttling of all pods on your host: https://gist.github.com/simonsj/ca7f532df95eec401a53f13ad31cbaff
CPU_STAT_FILE = '/sys/fs/cgroup/cpu,cpuacct/cpu.stat'
if File.exist?(CPU_STAT_FILE)
  nr_periods   = 0
  nr_throttled = 0

  File.read(CPU_STAT_FILE).each_line do |line|
    key, value = line.split(" ")

    case key
    when "nr_throttled"
      # break if there's no throttling
      if value == "0"
        STDOUT.puts "No throttling"
        break
      end

      nr_throttled = value.to_i
    when "nr_periods"
      # break if request/limits not set (nr_periods 0)
      if value == "0"
        STDOUT.puts "No periods monitored: no limit set?"
        break
      end

      nr_periods = value.to_f
    end
  end

  if nr_periods > 0 && nr_throttled > 0
    STDOUT.puts "#{nr_throttled/nr_periods}, nr_throttled/nr_periods, #{nr_throttled}/#{nr_periods}"
  end
end
