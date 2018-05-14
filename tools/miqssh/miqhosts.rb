#!/usr/bin/env ruby
#
# Parse miqhosts file for use with miqssh etc.
#

# Method load_file to read the hosts file and create useful datastructures.
def load_file(file)
  data = {} # Hash keyed on group name.  Each hash value to have an array of hosts.

  File.open(file).each do |line|
    next if line =~ /^#/
    next if line =~ /^$/
    next if line =~ /^\s+$/
    line.chomp!
    line.downcase!
    host, group_csv = line.split(/\s+/)
    groups = group_csv.split(",")
    # Add host to each of the specified groups.
    groups.each do |group|
      data[group.to_sym] = [] if data[group.to_sym].nil?
      data[group.to_sym].push(host)
    end
    # Add host to the all group.
    data[:all] = [] if data[:all].nil?
    data[:all].push(host)
    # Add host to all_no_db group unless it is the db.
    data[:all_no_db] = [] if data[:all_no_db].nil?
    data[:all_no_db].push(host) unless groups.include?("db")
  end
  # Sort and uniq the arrays of hosts.
  data.each_key do |k|
    data[k].uniq!
    data[k].sort!
  end
end

# Method to list the valid groups.
def list_groups(data)
  groups = []
  data.each_key { |k| groups.push(k.to_s) }
  puts groups.sort.join(" ")
end

# Method to list the servers belonging to the specified group.
def list_servers(data, group)
  groups = group.split(',')
  servers = []
  groups.each { |g| servers.push(data[g.to_sym]) }
  puts servers.uniq.sort.join(" ")
end

file = ARGV[0]
command = ARGV[1]
group = ARGV[2]

data = load_file(file)

if command == "list_groups"
  list_groups(data)
elsif command == "list_servers"
  list_servers(data, group)
end
