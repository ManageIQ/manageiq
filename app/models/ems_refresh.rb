module EmsRefresh
  extend EmsRefresh::SaveInventory
  extend EmsRefresh::SaveInventoryCloud
  extend EmsRefresh::SaveInventoryInfra
  extend EmsRefresh::SaveInventoryContainer
  extend EmsRefresh::SaveInventoryMiddleware
  extend EmsRefresh::SaveInventoryHelper
  extend EmsRefresh::SaveInventoryProvisioning
  extend EmsRefresh::SaveInventoryConfiguration
  extend EmsRefresh::SaveInventoryOrchestrationStacks
  extend EmsRefresh::SaveInventoryNetworks
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

  def self.queue_refresh(target, id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = get_ar_objects(target, id)

    # Group the target refs by zone and role
    targets_by_ems = targets.each_with_object(Hash.new { |h, k| h[k] = [] }) do |t, h|
      e = if t.kind_of?(EmsRefresh::Manager)
            t
          elsif t.kind_of?(Storage)
            t.ext_management_systems.first
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
    targets_by_ems.each do |ems, ts|
      ts = ts.collect { |t| [t.class.to_s, t.id] }.uniq
      queue_merge(ts, ems)
    end
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

  def self.queue_merge(targets, ems)
    # Items will be naturally serialized since there is a dedicated worker.
    MiqQueue.put_or_update(
      :queue_name  => MiqEmsRefreshWorker.queue_name_for_ems(ems),
      :class_name  => name,
      :method_name => 'refresh',
      :role        => "ems_inventory",
      :zone        => ems.my_zone
    ) do |msg, item|
      targets = msg.nil? ? targets : (msg.args[0] | targets)
      item.merge(
        :args        => [targets],
        :msg_timeout => queue_timeout,
        :task_id     => nil)
    end
  end

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

  #
  # Inventory saving for Reconfigure VM Task event
  #

  def self.reconfig_refresh(vm)
    ManageIQ::Providers::Vmware::InfraManager::Refresher.reconfig_refresh(vm)
  end

  def self.reconfig_save_vm_inventory(vm, hashes)
    return if hashes.nil?
    log_header = "Vm: [#{vm.name}], id: [#{vm.id}]"

    reconfig_find_lans_inventory(vm.host, hashes[:uid_lookup][:lans].values)
    reconfig_find_storages_inventory(hashes[:uid_lookup][:storages].values)
    hash = hashes[:vms].first

    child_keys = [:operating_system, :hardware]
    remove_keys = child_keys

    begin
      raise MiqException::MiqIncompleteData if hash[:invalid]

      _log.info("#{log_header} Updating Vm [#{vm.name}] id: [#{vm.id}] location: [#{vm.location}] storage id: [#{vm.storage_id}] uid_ems: [#{vm.uid_ems}]")
      vm.update_attributes!(hash.except(*remove_keys))
      save_child_inventory(vm, hash, child_keys)
      vm.save!
      hash[:id] = vm.id
    rescue => err
      # If a vm failed to process, mark it as invalid and log an error
      hash[:invalid] = true
      name = hash[:name] || hash[:uid_ems] || hash[:ems_ref]
      if err.kind_of?(MiqException::MiqIncompleteData)
        _log.warn("#{log_header} Processing Vm: [#{name}] failed with error [#{err}]. Skipping Vm.")
      else
        raise if EmsRefresh.debug_failures
        _log.error("#{log_header} Processing Vm: [#{name}] failed with error [#{err}]. Skipping Vm.")
        _log.log_backtrace(err)
      end
    end
  end

  def self.reconfig_find_lans_inventory(host, hashes)
    return if hashes.nil?
    lans = host.lans
    hashes.each do |h|
      found = lans.detect { |l| l.uid_ems == h[:uid_ems] }
      h[:id] = found.id if found
    end
  end

  def self.reconfig_find_storages_inventory(hashes)
    return if hashes.nil?

    # Query for all of the storages ahead of time
    locs, names = hashes.partition { |h| h[:location] }
    locs.collect!  { |h| h[:location] }
    names.collect! { |h| h[:name] }
    locs  = Storage.where("location IN (?)", locs) unless locs.empty?
    names = Storage.where("location IS NULL AND name IN (?)", names) unless names.empty?

    hashes.each do |h|
      found = if h[:location]
                locs.detect { |s| s.location == h[:location] }
              else
                names.detect { |s| s.name == h[:name] }
              end

      h[:id] = found.id if found
    end
  end
end
