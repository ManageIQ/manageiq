module EmsRefresh
  extend EmsRefresh::SaveInventory
  extend EmsRefresh::SaveInventoryCloud
  extend EmsRefresh::SaveInventoryInfra
  extend EmsRefresh::SaveInventoryContainer
  extend EmsRefresh::SaveInventoryHelper
  extend EmsRefresh::SaveInventoryProvisioning
  extend EmsRefresh::SaveInventoryConfiguration
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
    EmsRefresh::Refreshers::VcRefresher.init_console(use_vim_broker)
  end

  cache_with_timeout(:queue_timeout) { MiqEmsRefreshWorker.worker_settings[:queue_timeout] || 60.minutes }

  def self.queue_refresh(target, id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = self.get_ar_objects(target, id)

    # Group the target refs by zone and role
    targets_by_ems = targets.each_with_object(Hash.new {|h, k| h[k] = Array.new}) do |t, h|
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
      else
        nil
      end

      h[e] << t unless e.nil?
    end

    # Queue the refreshes
    targets_by_ems.each do |ems, ts|
      ts = ts.collect { |t| [t.class.to_s, t.id] }.uniq
      self.queue_merge(ts, ems)
    end
  end

  def self.refresh(target, id = nil)
    EmsRefresh.init_console if MiqEnvironment::Process.is_rails_console?

    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = self.get_ar_objects(target, id)

    # Split the targets into refresher groups
    groups = targets.group_by do |t|
      ems = case
            when t.respond_to?(:ext_management_system) then t.ext_management_system
            when t.respond_to?(:manager)               then t.manager
            else                                            t
            end
      next if ems.nil? # archived Vm
      ems.kind_of?(EmsVmware) ? "vc" : ems.emstype.to_s
    end

    # Do the refreshes
    groups.each do |g, group_targets|
      next if g.nil?
      self::Refreshers.const_get("#{g.to_s.camelize}Refresher").refresh(group_targets)
    end
  end

  def self.get_ar_objects(target, id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, an array of references
    target = [[target, id]] unless id.nil?
    target = [target] unless target.kind_of?(Array)

    return target unless target[0].kind_of?(Array)

    # Group by type for a more optimized search
    targets_by_type = target.each_with_object(Hash.new {|h, c| h[c] = Array.new}) do |t, h|
      # Take care of both String or Class type being passed in
      c = t[0].kind_of?(Class) ? t[0] : t[0].to_s.constantize
      if [VmOrTemplate, Host, ExtManagementSystem].none? { |k| c.is_or_subclass_of?(k) }
        $log.warn "MIQ(#{self.name}.get_ar_objects) Unknown target type: [#{c}]."
        next
      end

      h[c] << t[1]
    end

    # Do lookups to get ActiveRecord objects
    return targets_by_type.each_with_object([]) do |(c, ids), a|
      ids.uniq!

      recs = c.where(:id => ids)
      recs = recs.includes(:ext_management_system) unless c.ancestors.include?(ExtManagementSystem)

      if recs.length != ids.length
        missing = ids - recs.collect(&:id)
        $log.warn "MIQ(#{self.name}.get_ar_objects) Unable to find a record for [#{c}] ids: #{missing.inspect}."
      end

      a.concat(recs)
    end
  end

  def self.queue_merge(targets, ems)
    # Items will be naturally serialized since there is a dedicated worker.
    MiqQueue.put_or_update(
      :queue_name  => MiqEmsRefreshWorker.queue_name_for_ems(ems),
      :class_name  => self.name,
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
        self.log_inv_debug_trace(v, "#{log_header}  ", depth - 1)
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

    return ret.join(", ")
  end

  #
  # Inventory saving for Reconfigure VM Task event
  #

  def self.reconfig_refresh(vm)
    EmsRefresh::Refreshers::VcRefresher.reconfig_refresh(vm)
  end

  def self.reconfig_save_vm_inventory(vm, hashes)
    return if hashes.nil?
    log_header = "MIQ(#{self.name}.reconfig_save_vm_inventory) Vm: [#{vm.name}], id: [#{vm.id}]"

    reconfig_find_lans_inventory(vm.host, hashes[:uid_lookup][:lans].values)
    reconfig_find_storages_inventory(hashes[:uid_lookup][:storages].values)
    hash = hashes[:vms].first

    child_keys = [:operating_system, :hardware]
    remove_keys = child_keys

    begin
      raise MiqException::MiqIncompleteData if hash[:invalid]

      $log.info("#{log_header} Updating Vm [#{vm.name}] id: [#{vm.id}] location: [#{vm.location}] storage id: [#{vm.storage_id}] uid_ems: [#{vm.uid_ems}]")
      vm.update_attributes!(hash.except(*remove_keys))
      save_child_inventory(vm, hash, child_keys)
      vm.save!
      hash[:id] = vm.id
    rescue => err
      # If a vm failed to process, mark it as invalid and log an error
      hash[:invalid] = true
      name = hash[:name] || hash[:uid_ems] || hash[:ems_ref]
      if err.kind_of?(MiqException::MiqIncompleteData)
        $log.warn("#{log_header} Processing Vm: [#{name}] failed with error [#{err}]. Skipping Vm.")
      else
        raise if EmsRefresh.debug_failures
        $log.error("#{log_header} Processing Vm: [#{name}] failed with error [#{err}]. Skipping Vm.")
        $log.log_backtrace(err)
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
