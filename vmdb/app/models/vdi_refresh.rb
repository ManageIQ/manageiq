module VdiRefresh
  extend VdiRefresh::SaveInventory
  extend EmsRefresh::SaveInventoryHelper

  def self.debug_trace
    # TODO: Replace with configuration option
    false
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

  def self.queue_refresh(target, id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = self.get_ar_objects(target, id)

    # Group the target refs by zone
    targets_by_zone = targets.each_with_object(Hash.new {|h, k| h[k] = Array.new}) do |t, h|
      z = if t.kind_of?(VdiFarm)
        t.my_zone
      elsif t.respond_to?(:vdi_farm) && t.vdi_farm
        t.vdi_farm.my_zone
      else
        nil
      end

      h[z] << t unless z.nil?
    end

    # Queue the refreshes
    targets_by_zone.each do |z, ts|
      ts = ts.collect { |t| [t.class.to_s, t.id] }.uniq
      self.queue_merge(ts, z)
    end
  end

  def self.refresh(target, id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, or an array of references
    targets = self.get_ar_objects(target, id)

    # Split the targets into refresher groups
    groups = targets.each_with_object(Hash.new {|h, k| h[k] = Array.new}) do |t, h|
      # Determine the group
      farm = t.kind_of?(VdiFarm) ? t : t.vdi_farm
      h[farm.vendor.to_sym] << t
    end

    # Do the refreshes
    [:citrix, :vmware].each do |g|
      self::Refreshers.const_get("#{g.to_s.camelize}Refresher").refresh(groups[g]) if groups.has_key?(g)
    end
  end

  def self.get_ar_objects(target, id = nil)
    # Handle targets passed as a single class/id pair, an array of class/id pairs, an array of references
    target = [[target, id]] unless id.nil?
    target = [target] unless target.kind_of?(Array)

    return target unless target[0].kind_of?(Array)

    # Group by type for a more optimized search
    targets_by_type = target.each_with_object(Hash.new {|h, k| h[k] = Array.new}) do |t, h|
      # Take care of both String or Class type being passed in
      c = t[0].kind_of?(Class) ? t[0] : t[0].to_s.constantize
      if [VdiFarm].none? { |k| c.is_or_subclass_of?(k) }
        $log.warn "MIQ(#{self.name}.get_ar_objects) Unknown target type: [#{c}]."
        next
      end

      h[c] << t[1]
    end

    # Do lookups to get ActiveRecord objects
    return targets_by_type.each_with_object([]) do |(c, ids), a|
      ids.uniq!

      recs = c.where(:id => ids).all

      if recs.length != ids.length
        missing = ids - recs.collect {|r| r.id}
        $log.warn "MIQ(#{self.name}.get_ar_objects) Unable to find a record for [#{c}] ids: #{missing.inspect}."
      end

      a.concat(recs)
    end
  end

  def self.queue_merge(targets, zone)
    MiqQueue.put_or_update(
      :queue_name  => "generic",
      :class_name  => self.name,
      :method_name => 'refresh',
      :role        => "vdi_inventory",
      :zone        => zone
    ) do |msg, item|
      targets = msg.nil? ? targets : (msg.args[0] | targets)
      item.merge(:args => [targets], :msg_timeout => 60.minutes)
    end
  end
end
