module EmsRefresh
  extend EmsRefresh::SaveInventory
  extend EmsRefresh::SaveInventoryBlockStorage
  extend EmsRefresh::SaveInventoryCloud
  extend EmsRefresh::SaveInventoryInfra
  extend EmsRefresh::SaveInventoryContainer
  extend EmsRefresh::SaveInventoryMiddleware
  extend EmsRefresh::SaveInventoryDatawarehouse
  extend EmsRefresh::SaveInventoryNetwork
  extend EmsRefresh::SaveInventoryObjectStorage
  extend EmsRefresh::SaveInventoryHelper
  extend EmsRefresh::SaveInventoryProvisioning
  extend EmsRefresh::SaveInventoryConfiguration
  extend EmsRefresh::SaveInventoryAutomation
  extend EmsRefresh::SaveInventoryOrchestrationStacks
  extend EmsRefresh::LinkInventory
  extend EmsRefresh::MetadataRelats
  extend EmsRefresh::VcUpdates

  def self.debug_trace
    # TODO: Replace with configuration option
    false
  end

  # If true, Refreshers will raise any exceptions encountered, instead
  # of quietly recording them as failures and continuing.
  mattr_accessor :debug_failures

  # Development helper method for setting up the selector specs for VC
  def self.init_console(use_vim_broker = false)
    ManageIQ::Providers::Vmware::InfraManager::Refresher.init_console(use_vim_broker)
  end

  cache_with_timeout(:queue_timeout) { MiqEmsRefreshWorker.worker_settings[:queue_timeout] || 60.minutes }

  def self.queue_refresh_task(target, id = nil)
    queue_refresh(target, id, :create_task => true)
  end

  def self.queue_refresh(target, id = nil, opts = {})
    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = get_ar_objects(target, id)

    # Group the target refs by zone and role
    targets_by_ems = targets.each_with_object(Hash.new { |h, k| h[k] = [] }) do |t, h|
      e = if t.kind_of?(EmsRefresh::Manager)
            t
          elsif t.respond_to?(:ext_management_system) && t.ext_management_system
            t.ext_management_system
          elsif t.respond_to?(:manager) && t.manager
            t.manager
          elsif t.kind_of?(Host) && t.acts_as_ems?
            t
          end

      h[e] << t unless e.nil?
    end

    # Queue the refreshes
    task_ids = targets_by_ems.collect do |ems, ts|
      ts = ts.collect { |t| [t.class.to_s, t.id] }.uniq
      queue_merge(ts, ems, opts[:create_task])
    end

    return task_ids if opts[:create_task]
  end

  def self.queue_refresh_new_target(target_hash, ems)
    MiqQueue.put(
      :queue_name  => MiqEmsRefreshWorker.queue_name_for_ems(ems),
      :class_name  => name,
      :method_name => 'refresh_new_target',
      :role        => "ems_inventory",
      :zone        => ems.my_zone,
      :args        => [target_hash, ems.id],
      :msg_timeout => queue_timeout,
      :task_id     => nil
    )
  end

  def self.refresh(target, id = nil)
    EmsRefresh.init_console if defined?(Rails::Console)

    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = get_ar_objects(target, id)

    # Split the targets into refresher groups
    groups = targets.group_by do |t|
      ems = case
            when t.respond_to?(:ext_management_system) then t.ext_management_system
            when t.respond_to?(:manager)               then t.manager
            else                                            t
            end
      ems.refresher if ems.respond_to?(:refresher)
    end

    # Do the refreshes
    groups.each do |refresher, group_targets|
      refresher.refresh(group_targets) if refresher
    end
  end

  def self.refresh_new_target(target_hash, ems_id)
    ems = ExtManagementSystem.find(ems_id)

    target = save_new_target(target_hash)
    if target.nil?
      _log.warn "Unknown target for event data: #{target_hash}."
      return
    end

    ems.refresher.refresh(get_ar_objects(target))
  end

  def self.get_ar_objects(target, single_id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, an array of references
    target = [[target, single_id]] unless single_id.nil?
    return [target] unless target.kind_of?(Array)
    return target unless target[0].kind_of?(Array)

    # Group by type for a more optimized search
    targets_by_type = target.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(c, id), h|
      # Take care of both String or Class type being passed in
      c = c.to_s.constantize unless c.kind_of?(Class)
      if [VmOrTemplate, Host, ExtManagementSystem].none? { |k| c <= k }
        _log.warn "Unknown target type: [#{c}]."
        next
      end

      h[c] << id
    end

    # Do lookups to get ActiveRecord objects
    targets_by_type.each_with_object([]) do |(c, ids), a|
      ids.uniq!

      recs = c.where(:id => ids)
      recs = recs.includes(:ext_management_system) unless c <= ExtManagementSystem

      if recs.length != ids.length
        missing = ids - recs.collect(&:id)
        _log.warn "Unable to find a record for [#{c}] ids: #{missing.inspect}."
      end

      a.concat(recs)
    end
  end

  def self.queue_merge(targets, ems, create_task = false)
    queue_options = {
      :queue_name  => MiqEmsRefreshWorker.queue_name_for_ems(ems),
      :class_name  => name,
      :method_name => 'refresh',
      :role        => "ems_inventory",
      :zone        => ems.my_zone,
    }

    # If this is the only refresh then we will use the task we just created,
    # if we merge with another queue item then we will return its task_id
    task_id = nil

    # Items will be naturally serialized since there is a dedicated worker.
    MiqQueue.put_or_update(queue_options) do |msg, item|
      targets = msg.nil? ? targets : (msg.args[0] | targets)

      # If we are merging with an existing queue item we don't need a new
      # task, just use the original one
      task_id = if msg && msg.task_id
                  msg.task_id.to_i
                elsif create_task
                  task = create_refresh_task(ems, targets)
                  task.id
                end

      item.merge(
        :args         => [targets],
        :task_id      => task_id,
        :msg_timeout  => queue_timeout,
        :miq_callback => {
          :class_name  => task.class.name,
          :method_name => :queue_callback,
          :instance_id => task_id,
          :args        => ['Finished']
        }
      )
    end

    task_id
  end

  def self.create_refresh_task(ems, targets)
    task_options = {
      :action => "EmsRefresh(#{ems.name}) [#{targets}]",
      :userid => "system"
    }

    MiqTask.create(
      :name    => task_options[:action],
      :userid  => task_options[:userid],
      :state   => MiqTask::STATE_QUEUED,
      :status  => MiqTask::STATUS_OK,
      :message => "Queued the action: [#{task_options[:action]}] being run for user: [#{task_options[:userid]}]"
    )
  end
  private_class_method :create_refresh_task

  #
  # Helper methods for advanced debugging
  #

  def self.log_inv_debug_trace(inv, log_header, depth = 1)
    return unless debug_trace

    inv.each do |k, v|
      if depth == 1
        $log.debug "#{log_header} #{k.inspect}=>#{v.inspect}"
      else
        $log.debug "#{log_header} #{k.inspect}=>"
        log_inv_debug_trace(v, "#{log_header}  ", depth - 1)
      end
    end
  end

  def self.log_format_deletes(deletes)
    ret = deletes.collect do |d|
      s = "id: [#{d.id}]"

      [:name, :product_name, :device_name].each do |k|
        next unless d.respond_to?(k)
        v = d.send(k)
        next if v.nil?
        s << " #{k}: [#{v}]"
        break
      end

      s
    end

    ret.join(", ")
  end
end
