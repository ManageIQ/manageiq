require 'ostruct'
require 'optparse'

# Set to true to run this test
if false
  #$fsm_type = 'MultiStateTaskTest'
  $fsm_type = 'MultiStateTaskWithoutMiqQueueTest'

  class FsmTestSetup
    @@vm_state = {}

    def self.run_at_start
      clean_jobs_and_queue
      set_proxy_heartbeat_seconds
      set_vms_power_state
    end

    def self.run_at_exit
      puts "Exiting..."
      restore_proxy_heartbeat_seconds
      restore_vms_power_state
    end

    private

    def self.clean_jobs_and_queue
      begin
        Job.destroy_all({:type => $fsm_type})
        MiqQueue.destroy_all({:class_name => 'Job', :method_name => 'signal'})
      rescue => err
        puts err.to_s
        puts err.backtrace.join("\n")
      end
    end

    def self.set_vms_power_state
      Vm.find(:all).each do |v|
        @@vm_state[v.id] = v.state
        v.state = "off"
        v.save
      end
    end

    def self.restore_vms_power_state
      Vm.find(:all).each do |v|
        if @@vm_state[v.id]
          v.state = @@vm_state[v.id]
          v.save
        end
      end
    end

    def self.set_proxy_heartbeat_seconds(seconds = 60*60*24)
      MiqProxy.find(:all).each do |proxy|
        puts "set_proxy_heartbeat_seconds: proxy [#{proxy.id}] setting heartbeat to #{seconds} seconds"
        proxy.settings[:heartbeat_frequency_old] = proxy.settings[:heartbeat_frequency] if proxy.settings[:heartbeat_frequency]
        proxy.settings[:heartbeat_frequency] = seconds
        proxy.last_heartbeat = Time.now.utc
        proxy.save
      end
    end

    def self.restore_proxy_heartbeat_seconds
      MiqProxy.find(:all).each do |proxy|
        if proxy.settings[:heartbeat_frequency_old]
          puts "restore_proxy_heartbeat_seconds: proxy [#{proxy.id}] restoring heartbeat to #{proxy.settings[:heartbeat_frequency_old]} seconds"
          proxy.settings[:heartbeat_frequency] = proxy.settings[:heartbeat_frequency_old]
        end
        proxy.settings.delete(:heartbeat_frequency_old)
        proxy.save
      end
    end
  end

  defaults = {
    :total => 1
  }
  cfg = OpenStruct.new(defaults)

  opts = OptionParser.new
  opts.on('--total=val', 'Total number of jobs to create and run', Integer) {|val| cfg.total = val}
  opts.parse(*ARGV)

  ActiveRecord::Base.establish_connection(
    :adapter => "postgresql",
    :host => "localhost",
    :username => "root",
    :password => "smartvm",
    :database => "vmdb_production")

  trap("SIGINT") { puts "Interupt signal received, restoring settings"; FsmTestSetup.run_at_exit}
  FsmTestSetup.run_at_start

  vmdb_cfg = VMDB::Config.new("vmdb")
  vmdb_cfg.set(:repository_scanning, :Defaultsmartproxy, 1)
  vmdb_cfg.save

  job_count = 0
  loop do
    Vm.find(:all).each {|v|
      unless v.has_active_proxy?
        puts "Vm [#{v.name}] doesn't have an active proxy - skipping vm"
        next
      end
      break if job_count == cfg.total.to_i
      options = {
        :target_id => v.id,
        :target_class => v.class.to_s,
        :name => "#{$fsm_type} Job for Vm #{v.name}"
      }
      puts "Creating job: #{options[:name]}"
      Job.create_job($fsm_type, options)
      job_count += 1
    }
    break if job_count == cfg.total.to_i || job_count == 0
  end

  puts "Done, #{job_count} jobs were created"
  puts ""
  puts "Hit ^C to terminate test"

  initial_count = Job.find(:all, :conditions => ["type = ? and state != ?", $fsm_type, "finished"], :select => "id").length
  initial_start = Time.now
  results = {}
  loop do
    count = Job.find(:all, :conditions => ["type = ? and state != ?", $fsm_type, "finished"], :select => "id").length
    pending = Job.find(:all, :conditions=>["state = ? and dispatch_status = ?", "waiting_to_start", "pending"], :select =>"id").length
    completed = initial_count - count
    t_time = Time.now - initial_start
    avg_time = t_time/completed unless completed == 0
    avg_time ||= "---"
    puts "#{Time.now.utc} --- [#{t_time}] s elapsed, completed: [#{completed}], remaining: #{count}, pending: #{pending}, avg s to complete [#{avg_time}]" if results[count.to_s].nil?
    results[count.to_s] = "set"
    break if count == 0
    sleep 20
  end

  puts "All jobs processed"
  FsmTestSetup.run_at_exit
end
