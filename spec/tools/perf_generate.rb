require 'optimist'
ARGV.shift if ARGV[0] == '--'
opts = Optimist.options do
  banner "Generate metrics records.\n\nUsage: rails runner #{$0} [-- options]\n\nOptions:\n\t"
  opt :realtime,    "Realtime range",      :default => "4.hours"
  opt :hourly,      "Hourly range",        :default => "6.months"
  opt :vms,         "Number of VMs",       :default => 2000
  opt :hosts,       "Number of Hosts",     :default => 10
  opt :clusters,    "Number of Clusters",  :default => 2
  opt :ems,         "Number of EMSes",     :default => 1
  opt :storages,    "Number of Storages",  :default => 5
  opt :no_generate, "Skips generation of the import file"
  opt :no_import,   "Skips performing the actual import"
  opt :no_delete,   "Skips deleting of the generated files"
  opt :dry_run,     "Same as --no-generate --no-import --no-delete"
end
Optimist.die "script must be run with rails runner" unless Object.const_defined?(:Rails)
Optimist.die :realtime, "must be a number with method (e.g. 4.hours)"  unless opts[:realtime].number_with_method?
Optimist.die :hourly,   "must be a number with method (e.g. 6.months)" unless opts[:hourly].number_with_method?
opts[:no_generate] = opts[:no_import] = opts[:no_delete] = true if opts[:dry_run]

require 'ruby-progressbar'
require 'csv'

NUM_VMS, NUM_HOSTS, NUM_CLUSTERS, NUM_EMS, NUM_STORAGES, IMPORT_WINDOW =
  opts.values_at(:vms, :hosts, :clusters, :ems, :storages, :window)

REALTIME_START    = opts[:realtime].to_i_with_method.seconds.ago.utc.change(:min => 0, :sec => 0, :usec => 0) # beginning of hour
HOURLY_START      = opts[:hourly].to_i_with_method.seconds.ago.utc.beginning_of_day

VMS_PER_HOST      = NUM_VMS / NUM_HOSTS
HOSTS_PER_CLUSTER = NUM_HOSTS / NUM_CLUSTERS

# Estimate the total time for the process
HOURLY_PER_HOUR   = NUM_STORAGES + NUM_VMS + NUM_HOSTS + NUM_CLUSTERS + NUM_EMS + 2 # 2 => MiqRegion and MiqEnterprise
REALTIME_PER_HOUR = (NUM_VMS + NUM_HOSTS) * 180
realtime_count = hourly_count = 0
(HOURLY_START...Time.now.utc).step_value(1.hour) do |hour|
  realtime_count += REALTIME_PER_HOUR if hour >= REALTIME_START
  hourly_count += HOURLY_PER_HOUR
end

IMPORT_REALTIME_FNAME = File.expand_path(File.join(File.dirname(__FILE__), "import_realtime.csv"))
IMPORT_HOURLY_FNAME = File.expand_path(File.join(File.dirname(__FILE__), "import_hourly.csv"))
METRICS_COLS = [:capture_interval_name, :resource_type, :resource_id, :timestamp]

puts <<-EOL
Importing metrics for:
  EMS:            #{NUM_EMS}
  Storages:       #{NUM_STORAGES}
  Clusters:       #{NUM_CLUSTERS}
  Hosts:          #{NUM_HOSTS}
  VMs:            #{NUM_VMS}

  Realtime from:  #{REALTIME_START.iso8601}
  Hourly from:    #{HOURLY_START.iso8601}

  Number of realtime rows: #{Class.new.extend(ActionView::Helpers::NumberHelper).number_with_delimiter(realtime_count)}
  Number of hourly rows:   #{Class.new.extend(ActionView::Helpers::NumberHelper).number_with_delimiter(hourly_count)}

EOL

unless opts[:no_generate]
  $pbar = ProgressBar.create(:title => "generate", :total => realtime_count + hourly_count, :autofinish => false)
  $out_csv_realtime = CSV.open(IMPORT_REALTIME_FNAME, "wb", :row_sep => "\n")
  $out_csv_realtime << METRICS_COLS
  $out_csv_hourly   = CSV.open(IMPORT_HOURLY_FNAME, "wb", :row_sep => "\n")
  $out_csv_hourly << METRICS_COLS

  def insert_realtime(klass, id, timestamp)
    180.times do |rt_count|
      $out_csv_realtime << ["realtime", klass, id, (timestamp + 20 * rt_count).iso8601]
      $pbar.increment
    end
  end

  def insert_hourly(klass, id, timestamp)
    $out_csv_hourly << ["hourly", klass, id, timestamp.iso8601]
    $pbar.increment
  end

  # Returns the ids of Hosts and Vms as if they were processed via capture or rollup:
  # Yields Vms from Host 1, Host 1, Vms from Host 2, Host 2, etc.
  def with_vms_and_hosts
    NUM_HOSTS.times do |h_id|
      VMS_PER_HOST.times do |v_count|
        v_id = h_id * VMS_PER_HOST + v_count
        yield "Vm", v_id + 1
      end
      yield "Host", h_id + 1
    end
  end

  (HOURLY_START...Time.now.utc).step_value(1.hour) do |hour|
    # Only start "capturing" the realtime data once it's in range
    if hour >= REALTIME_START
      # "capture" the realtime data from Hosts and Vms
      with_vms_and_hosts do |klass, id|
        insert_realtime(klass, id, hour)
      end
    end

    last_hour = hour - 1.hour

    # "capture" hourly Storage data from the last hour
    (1..NUM_STORAGES).each do |id|
      insert_hourly("Storage", id, last_hour)
    end

    # "rollup" hourly data from the last hour for all
    with_vms_and_hosts do |klass, id|
      insert_hourly(klass, id, last_hour)
    end
    (1..NUM_CLUSTERS).each { |id| insert_hourly("EmsCluster", id, last_hour) }
    (1..NUM_EMS).each { |id| insert_hourly("ExtManagementSystem", id, last_hour) }
    insert_hourly("MiqRegion", 1, last_hour)
    insert_hourly("MiqEnterprise", 1, last_hour)
  end

  $out_csv_realtime.close
  $out_csv_hourly.close
  $pbar.finish
end

unless opts[:no_import]
  $pbar = ProgressBar.create(:title => "import", :total => realtime_count + hourly_count, :autofinish => false)
  # PostgreSQL specific
  ActiveRecord::Base.connection.execute(
    "COPY metrics (#{METRICS_COLS.join(",")}) FROM '#{IMPORT_REALTIME_FNAME}' WITH CSV HEADER"
  )
  $pbar.progress += realtime_count
  # PostgreSQL specific
  ActiveRecord::Base.connection.execute(
    "COPY metric_rollups (#{METRICS_COLS.join(",")}) FROM '#{IMPORT_HOURLY_FNAME}' WITH CSV HEADER"
  )
  $pbar.finish
end

unless opts[:no_delete]
  File.delete(IMPORT_REALTIME_FNAME) if File.exist?(IMPORT_REALTIME_FNAME)
  File.delete(IMPORT_HOURLY_FNAME)   if File.exist?(IMPORT_HOURLY_FNAME)
end
