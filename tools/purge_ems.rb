#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'optimist'

ARGV.shift if ARGV[0] == '--' # if invoked with rails runner
opts = Optimist.options do
  banner "Purge managements system records in the background via the queue.\n\nUsage: ruby #{$0} [options]\n\nOptions:\n\t"
  opt :id,      "Mangement System id",                                         :short => :i, :type => :integer,                    :required => true
  opt :follow,  "Follow the progress or exit after creating messages",         :short => :f, :type => :string,  :default => "true"
  opt :batch,   "How many rows in each relationship to be deleted in a batch", :short => :b, :type => :integer, :default => 1_000
  opt :timeout, "How many minutes should each message be allowed to run",      :short => :t, :type => :integer, :default => 30
end

Optimist.die :id,      "must be a positive number"                             if opts[:id] < 1
Optimist.die :batch,   "must be a positive number"                             if opts[:batch] < 1
Optimist.die :timeout, "must be a positive number greater than or equal to 10" if opts[:timeout] < 10

opts[:follow] = opts[:follow].to_s.downcase
Optimist.die :follow, "must be true or false" unless %w[true false].include?(opts[:follow])

RELATIONSHIP_DESTROY_METHOD = "destroy".freeze
EMS_DESTROY_METHOD          = "destroy_queue".freeze
ZONE                        = nil                    # Will queue for any zone
PRIORITY                    = MiqQueue::LOW_PRIORITY # Don't block other work

def log(msg)
  $log.info("MIQ(#{__FILE__}) #{msg}")
  puts msg
end

def current_backlog
  MiqQueue.where(:method_name => [EMS_DESTROY_METHOD, RELATIONSHIP_DESTROY_METHOD], :zone => ZONE).count
end

id = opts[:id]
ems = ExtManagementSystem.find(id)
if ems.enabled?
  log("Pausing management system with id: #{id} #{ems.name}...")
  ems.pause!
  log("Pausing management system with id: #{ems.id} #{ems.name}...Complete")
end

if ems.reload.enabled?
  log("Management system with id: #{ems.id} #{ems.name} is still enabled!")
  exit 1
end

# Watching the destroy queue messages be processed can take a long time so terminal disconnects
# are likely.  Therefore, if running it again, detect when it's in progress, skip queueing more
# and skip right to watching the updated progress if desired.
create_messages = true
backlog = current_backlog
if backlog > 0
  log("A backlog of #{backlog} work items is already in progress, skipping creating more.")
  create_messages = false
end

if create_messages
  batch = opts[:batch]
  timeout = opts[:timeout].to_i.minutes
  log("Adding work items with batches of #{batch}...")
  ems.class.reflections.select { |_, v| v.options[:dependent] }.map { |n, _v| ems.send(n) }.each do |rel|
    next unless rel

    log("  Adding #{rel.klass}")
    rel.order(:id).pluck(:id).each_slice(batch) do |x|
      MiqQueue.put(
        :class_name  => rel.klass.to_s,
        :method_name => RELATIONSHIP_DESTROY_METHOD,
        :args        => [x],
        :msg_timeout => timeout,
        :priority    => PRIORITY,
        :zone        => ZONE
      )
    end
  end

  log("Adding work items with batches of #{batch}...Complete")

  MiqQueue.put(
    :class_name  => ems.class,
    :instance_id => ems.id,
    :method_name => EMS_DESTROY_METHOD,
    :msg_timeout => timeout,
    :priority    => PRIORITY,
    :zone        => ZONE
  )
end

if opts[:follow] == "true"
  start_backlog = current_backlog
  log("Destruction in progress...#{start_backlog} initial items")
  require 'ruby-progressbar'

  # Example format output:
  # Progress: 5/10 |=====     |
  pbar = ProgressBar.create(:title => "Progress", :total => start_backlog, :autofinish => false, :format => "%t: %c/%C |%B|")
  done = 0
  loop do
    remaining = current_backlog
    newly_finished = start_backlog - remaining - done
    done += newly_finished
    pbar.progress += newly_finished

    break if remaining == 0
    sleep 10
  end
  pbar.finish
  log("Destruction in progress...Complete")
end
