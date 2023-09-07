#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'optimist'

ARGV.shift if ARGV[0] == '--' # if invoked with rails runner
batch_message = "For each relationship, the number of rows to be removed in a batch. A lower number may decrease memory usage but also take longer."
opts = Optimist.options do
  banner "Purge management system records in the background via the queue.\n\nUsage: ruby #{$PROGRAM_NAME} [options]\n\nOptions:\n\t"
  opt :id,      "Management System id",                                         :type => :integer, :required => true
  opt :follow,  "Follow the progress or exit after creating work items.",       :type => :boolean, :default => true
  opt :batch,   batch_message,                                                  :type => :integer, :default => 1_000
  opt :timeout, "The number of minutes each work item will be allowed to run.", :type => :integer, :default => 30
end

Optimist.die :id,      "must be a positive number"                             if opts[:id] < 1
Optimist.die :batch,   "must be a positive number"                             if opts[:batch] < 1
Optimist.die :timeout, "must be a positive number greater than or equal to 10" if opts[:timeout] < 10

DESTROY_METHOD = "destroy".freeze
ZONE           = nil                    # Will queue for any zone
PRIORITY       = MiqQueue::LOW_PRIORITY # Don't block other work

def log(msg)
  $log.info("MIQ(#{__FILE__}) #{msg}")
  puts msg
end

def current_backlog
  MiqQueue.where(:method_name => DESTROY_METHOD, :zone => ZONE, :priority => PRIORITY).count
end

def before_destroy_ems(ems)
  if ems.enabled?
    log("Pausing management system with id: #{ems.id} #{ems.name}...")
    ems.pause!
    log("Pausing management system with id: #{ems.id} #{ems.name}...Complete")
  end

  log("Removing any workers for management system with id: #{ems.id} #{ems.name}...")
  ems.ems_workers.each(&:kill_async)
  ems.wait_for_ems_workers_removal
  log("Removing any workers for management system with id: #{ems.id} #{ems.name}...Complete")
end

def existing_backlog?
  # Watching the destroy queue messages be processed can take a long time so terminal disconnects
  # are likely.  Therefore, if running it again, detect when it's in progress, skip queueing more
  # and skip right to watching the updated progress if desired.
  current_backlog > 0
end

def destroy_ems_in_batches(ems, batch, timeout, priority)
  before_destroy_ems(ems)

  if existing_backlog?
    log("A backlog of work items is already in progress, skipping creating more.")
    return
  end

  log("Adding work items with batches of #{batch}...")
  ems.class.reflections.select { |_, v| v.options[:dependent] }.map { |n, _v| ems.send(n) }.each do |rel|
    next unless rel

    log("  Adding #{rel.klass}")
    rel.order(:id).pluck(:id).each_slice(batch) do |x|
      MiqQueue.put(
        :class_name  => rel.klass.to_s,
        :method_name => DESTROY_METHOD,
        :args        => [x],
        :msg_timeout => timeout,
        :priority    => priority,
        :zone        => ZONE
      )
    end
  end

  log("Adding work items with batches of #{batch}...Complete")

  MiqQueue.put(
    :class_name  => ems.class,
    :instance_id => ems.id,
    :method_name => DESTROY_METHOD,
    :msg_timeout => timeout,
    :priority    => priority,
    :zone        => ZONE
  )
end

def destroy_parent_ems_in_batches(ems_id, batch, timeout)
  ems     = ExtManagementSystem.find(ems_id)
  timeout = timeout.to_i.minutes

  log("Adding work items to remove child managers first...")
  ems.child_managers.each { |e| destroy_ems_in_batches(e, batch, timeout, PRIORITY - 10) }
  log("Adding work items to remove child managers first...Complete")

  log("Adding work items to remove targeted management system...")
  destroy_ems_in_batches(ems, batch, timeout, PRIORITY)
  log("Adding work items to remove targeted management system...Complete")
rescue ActiveRecord::RecordNotFound
  log("Management System with id: #{ems_id} not found!")
  exit 1
end

destroy_parent_ems_in_batches(*opts.values_at(:id, :batch, :timeout))

if opts[:follow]
  start_backlog = current_backlog
  log("Destruction in progress...#{start_backlog} initial items")
  require 'ruby-progressbar'

  # Example format output:
  # Progress: 5/10 |=====     |
  pbar = ProgressBar.create(:title => "Progress", :total => start_backlog, :autofinish => false, :format => "%t: %c/%C |%B|")
  loop do
    remaining = current_backlog
    break if remaining == 0

    pbar.progress = start_backlog - remaining
    sleep 10
  end
  pbar.finish
  log("Destruction in progress...Complete")
end
