#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'trollop'

ARGV.shift if ARGV[0] == '--' # if invoked with rails runner
opts = Trollop.options do
  banner "Purge orphaned vim_performance_tag_values records.\n\nUsage: ruby #{$0} [options]\n\nOptions:\n\t"
  opt :search_window, "Window of records to scan when finding orpahns", :default => 1000
  opt :delete_window, "Window of orphaned records to delete at once",   :default => 50
  opt :purge_disabled_tag_values, "Also remove values for tags which are set to not collect data anymore"
end
Trollop.die :search_window, "must be a number greater than 0" if opts[:search_window] <= 0
Trollop.die :delete_window, "must be a number greater than 0" if opts[:delete_window] <= 0

def log(msg)
  $log.info("MIQ(#{__FILE__}) #{msg}")
  puts msg
end

formatter = Class.new.extend(ActionView::Helpers::NumberHelper)

require 'ruby-progressbar'
log("Purging orphaned tag values...")

# Determine all of the known metric ids in the tag values table
log("Finding known metric ids...")
perf_ids = Hash.new { |h, k| h[k] = [] }
# TODO: there is probably a way to do this without bringing the ids back
t = Benchmark.realtime do
  VimPerformanceTagValue.select("metric_type, metric_id").distinct.order(nil).each { |v| perf_ids[v.metric_type] << v.metric_id }
end
perf_ids_count = perf_ids.inject(0) { |sum, (_type, ids)| sum + ids.length }
log("Finding known metric ids...Complete - #{formatter.number_with_delimiter(perf_ids_count)} records (#{t}s)")

if perf_ids_count > 0
  # Determine the orphaned tag values by finding deleted metric ids
  log("Finding deleted metric ids...")
  deleted_ids = Hash.new { |h, k| h[k] = [] }
  pbar = ProgressBar.create(:title => "Searching", :total => perf_ids_count, :autofinish => false)
  perf_ids.each do |type, ids|
    klass = type.constantize
    ids.each_slice(opts[:search_window]) do |ids_window|
      found_ids = klass.where(:id => ids_window).pluck(:id)
      deleted_ids[type] += (ids_window - found_ids)
      pbar.progress += ids_window.length
    end
  end
  pbar.finish
  deleted_ids_count = deleted_ids.inject(0) { |sum, (_type, ids)| sum + ids.length }
  log("Finding deleted metric ids...Complete - #{formatter.number_with_delimiter(deleted_ids_count)} records")

  perf_ids = nil # Allow GC to collect the huge array

  if deleted_ids_count > 0
    # Delete the orphaned tag values by the known deleted metric ids
    log("Deleting orphaned tag values...")
    pbar = ProgressBar.create(:title => "Deleting", :total => deleted_ids_count, :autofinish => false)
    deleted_ids.each do |type, ids|
      ids.each_slice(opts[:delete_window]) do |ids_window|
        VimPerformanceTagValue.where(:metric_type => type, :metric_id => ids_window).delete_all
        pbar.progress += ids_window.length
      end
    end
    pbar.finish
    log("Deleting orphaned tag values...Complete")
  end

  deleted_ids = nil

  if opts[:purge_disabled_tag_values]
    query = VimPerformanceTagValue.where.not(:category => Classification.category_names_for_perf_by_tag).select(:id)

    log("Deleting tag values for disabled tags...")
    total_disabled_count = query.count
    pbar = ProgressBar.create(:title => "Deleting disabled tag values", :total => total_disabled_count, :autofinish => false)

    loop do
      batch_ids = query.limit(opts[:delete_window])
      count = VimPerformanceTagValue.where(:id => batch_ids).delete_all

      pbar.progress += count
      break if count == 0
    end

    pbar.finish
    log("Deleting tag values for disabled tags...Complete - #{formatter.number_with_delimiter(total_disabled_count)} records")
  end
end

log("Purging orphaned tag values...Complete")
