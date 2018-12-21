#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

require 'trollop'

options = Trollop.options(ARGV) do
  banner "USAGE:  #{__FILE__} -c|--commit\n" \
         "Example (Commit):  #{__FILE__} --commit\n" \
         "Example (Dry Run): #{__FILE__}         \n" \

  opt :commit, "Commit to database. The default behavior is to do a dry run", :short => "c"
end

read_only = !options[:commit]

puts
puts

if read_only
  puts "READ ONLY MODE"
else
  puts "COMMIT MODE"
end

puts

ActiveRecord::Base.transaction do
  condition_for_mapped_tags = ContainerLabelTagMapping::TAG_PREFIXES.map { "tags.name LIKE ?" }.join(' OR ')
  tag_values = ContainerLabelTagMapping::TAG_PREFIXES.map { |x| "#{x}%:%" }

  Classification.where.not(:id => Classification.region_to_range) # only other regions(not current, we expected that current region is global)
                .where(:classifications => {:parent_id => 0}) # only categories
                .includes(:tag, :children).references(:tag, :children)
                .where(condition_for_mapped_tags, *tag_values) # only mapped categories
                .find_each do |category|
    new_parent_category = Classification.in_my_region.find_by(:description => category.description)

    if new_parent_category
      print "Using..."
    else
      new_parent_category = category.dup
      new_parent_category.save unless read_only # create in current region (global region is expected), it will create also tag instance
      print "Creating..."
    end

    puts "parent category #{new_parent_category.description} with tag: #{new_parent_category.tag.name} - from region #{category.region_id} to region #{new_parent_category.region_id}"

    category.entries.each do |entry|
      new_entry = Classification.in_my_region.find_by(:description => entry.description)
      if new_entry
        print "Using...."
      else
        new_entry = entry.dup
        new_entry.parent_id = new_parent_category.id
        new_entry.save unless read_only # it will create also tag instance
        print "Creating..."
      end
      puts "entry category #{new_entry.description} of #{new_parent_category.description} - from region #{category.region_id} to region #{new_entry.region_id}"
    end
  end
end

puts

if read_only
  puts "READ ONLY MODE - no changes have been applied"
else
  puts "COMMIT MODE - changes have been applied"
end

puts

Trollop.educate if !options[:help] && !options[:commit] # display help message only in Dry Run
