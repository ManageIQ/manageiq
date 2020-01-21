#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

require 'csv'
CSV.open("reports.csv", "w") do |csv|
  csv << %w(Name Title Group Sorting Graph Filter)

  MiqReport.order(:name).each do |rpt|
    next if rpt.rpt_group == "Custom" || rpt.rpt_group == "Compare"

    sort   = rpt.sortby.join(", ")   if rpt.sortby
    filter = rpt.conditions.to_human if rpt.conditions
    graph  = rpt.graph ? "Yes" : "No"

    csv << [rpt.name, rpt.title, rpt.rpt_group, sort, graph, filter]
  end
end
