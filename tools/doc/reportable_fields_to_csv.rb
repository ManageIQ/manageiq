#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

models = MiqReport.reportable_models.collect do |m|
  [Dictionary.gettext(m, :type => :model, :notfound => :titleize).pluralize, m]
end.sort

require 'csv'
CSV.open("reportable_fields.csv", "w") do |csv|
  csv << %w(model_display_name model field_display_name field)

  models.each do |model_display_name, model|
    puts "Generating list for #{model}"
    MiqExpression.reporting_available_fields(model).each do |field_display_name, field|
      csv << [model_display_name, model, field_display_name, field].map(&:strip)
    end
  end
end
