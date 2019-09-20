#!/usr/bin/env ruby
require File.expand_path("../config/environment", __dir__)

user = User.lookup_by_userid("admin")
if ARGV[0].nil?
  print "Password: "
  user.password = STDIN.noecho(&:gets).chomp
else
  user.password = ARGV[0]
end
user.save
puts "Password for admin user restored"
