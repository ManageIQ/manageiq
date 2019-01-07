#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

def print_records(recs, indent = '')
  return if recs.blank?

  recs = recs.sort_by { |r| r.name.downcase }
  recs.each do |r|
    puts "#{indent}- #{r.class}: #{r.name}"
    if r.kind_of?(VmdbDatabase)
      print_records(r.evm_tables, "  #{indent}")
    else
      print_records(r.try(:vmdb_indexes), "  #{indent}")
      print_records(r.try(:text_tables), "  #{indent}")
    end
  end
end

print_records(VmdbDatabase.includes(:evm_tables => [:vmdb_indexes, {:text_tables => :vmdb_indexes}]))
