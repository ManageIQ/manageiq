#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

puts "Deleting ems_metadata Relationships..."
Relationship.where(:relationship => "ems_metadata").delete_all
puts "Deleting ems_metadata Relationships...Complete"
