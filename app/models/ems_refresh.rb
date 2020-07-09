module EmsRefresh
  extend EmsRefresh::SaveInventory
  extend EmsRefresh::SaveInventoryCloud
  extend EmsRefresh::SaveInventoryInfra
  extend EmsRefresh::SaveInventoryNetwork
  extend EmsRefresh::SaveInventoryHelper
  extend EmsRefresh::LinkInventory

  def self.debug_trace
    Settings.ems_refresh[:debug_trace]
  end

  # If true, Refreshers will raise any exceptions encountered, instead
  # of quietly recording them as failures and continuing.
  mattr_accessor :debug_failures

  cache_with_timeout(:queue_timeout) { MiqEmsRefreshWorker.worker_settings[:queue_timeout] || 60.minutes }

  def self.queue_refresh_task(target, id = nil)
    queue_refresh(target, id, :create_task => true)
  end

  def self.queue_refresh(target, id = nil, opts = {})
    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = get_target_objects(target, id)

    # Group the target refs by zone and role
    targets_by_ems = targets.each_with_object(Hash.new { |h, k| h[k] = [] }) do |t, h|
      e = if t.kind_of?(EmsRefresh::Manager)
            t
          elsif t.respond_to?(:ext_management_system) && t.ext_management_system
            t.ext_management_system
          elsif t.respond_to?(:manager) && t.manager
            t.manager
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

  def self.refresh(target, id = nil)
    require "inventory_refresh"

    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = get_target_objects(target, id).uniq

    # Store manager records to avoid n+1 queries
    manager_by_manager_id = {}

    # Split the targets into refresher groups
    groups = targets.group_by do |t|
      ems = case
            when t.respond_to?(:ext_management_system) then t.ext_management_system
            when t.respond_to?(:manager_id)            then manager_by_manager_id[t.manager_id] ||= t.manager
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

  def self.get_target_objects(target, single_id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, an array of references
    target = [[target, single_id]] unless single_id.nil?
    return [target] unless target.kind_of?(Array)
    return target unless target[0].kind_of?(Array)

    # Group by type for a more optimized search
    targets_by_type = target.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(target_class, id), hash|
      # Take care of both String or Class type being passed in
      target_class = target_class.to_s.constantize unless target_class.kind_of?(Class)

      if ManageIQ::Providers::Inventory.persister_class_for(target_class).blank? &&
         [VmOrTemplate, Host, PhysicalServer, ExtManagementSystem, InventoryRefresh::Target].none? { |k| target_class <= k }
        _log.warn("Unknown target type: [#{target_class}].")
        next
      end

      hash[target_class] << id
    end

    # Do lookups to get ActiveRecord objects or initialize InventoryRefresh::Target for ids that are Hash
    targets_by_type.each_with_object([]) do |(target_class, ids), target_objects|
      ids.uniq!

      recs = if target_class <= InventoryRefresh::Target
               ids.map { |x| InventoryRefresh::Target.load(x) }
             else
               active_record_recs = target_class.where(:id => ids)
               active_record_recs = active_record_recs.includes(:ext_management_system) unless target_class <= ExtManagementSystem
               active_record_recs
             end

      if recs.length != ids.length
        missing = ids - recs.collect(&:id)
        _log.warn("Unable to find a record for [#{target_class}] ids: #{missing.inspect}.")
      end

      target_objects.concat(recs)
    end
  end

  def self.queue_merge(targets, ems, create_task = false)
    queue_options = {
      :queue_name  => ems.queue_name_for_ems_refresh,
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
      targets = msg.nil? ? targets : msg.data.concat(targets)
      targets = uniq_targets(targets)

      # If we are merging with an existing queue item we don't need a new
      # task, just use the original one
      task_id = if msg && msg.task_id
                  msg.task_id.to_i
                elsif create_task
                  task = create_refresh_task(ems, targets)
                  task.id
                end

      unless task_id.nil?
        item[:miq_callback] = {
          :class_name  => 'MiqTask',
          :method_name => :queue_callback,
          :instance_id => task_id,
          :args        => ['Finished']
        }
      end
      item.merge(
        :data        => targets,
        :task_id     => task_id,
        :miq_task_id => task_id,
        :msg_timeout => queue_timeout
      )
    end

    task_id
  end

  def self.create_refresh_task(ems, targets)
    targets = targets.collect { |target_class, target_id| [target_class.demodulize, target_id] }
    task_options = {
      :action => "EmsRefresh(#{ems.name}) [#{targets}]".truncate(255),
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

  def self.uniq_targets(targets)
    if targets.size > 1_000
      manager_refresh_targets, application_record_targets = targets.partition { |key, _| key == "InventoryRefresh::Target" }
      application_record_targets.uniq!
      manager_refresh_targets.uniq! { |_, value| value.values_at(:manager_id, :association, :manager_ref) }

      application_record_targets + manager_refresh_targets
    else
      targets
    end
  end
  private_class_method :uniq_targets

  #
  # Helper methods for advanced debugging
  #

  def self.log_inv_debug_trace(inv, log_header, depth = 1)
    return unless debug_trace

    inv.each do |k, v|
      if depth == 1
        $log.debug("#{log_header} #{k.inspect}=>#{v.inspect}")
      else
        $log.debug("#{log_header} #{k.inspect}=>")
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
