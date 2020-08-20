module EmsRefresh::LinkInventory
  def instance_with_id(klass, id)
    instances_with_ids(klass, id).first
  end

  def instances_with_ids(klass, id)
    klass.where(:id => id).select(:id, :name).to_a
  end

  # Link HABTM relationships for the object, via the accessor, for the records
  #   specified by the hashes.
  def link_habtm(object, hashes, accessor, model, do_disconnect = true)
    return unless object.respond_to?(accessor)

    prev_ids = object.send(accessor).collect(&:id)
    new_ids  = hashes.collect { |s| s[:id] }.compact unless hashes.nil?
    update_relats_by_ids(prev_ids, new_ids,
                         do_disconnect ? proc { |s| object.send(accessor).delete(instance_with_id(model, s)) } : nil, # Disconnect proc
                         proc { |s| object.send(accessor) << instance_with_id(model, s) },                            # Connect proc
                         proc { |ss| object.send(accessor) << instances_with_ids(model, ss) }) # Bulk connect proc
  end

  #
  # Helper methods for EMS metadata linking
  #
  def update_relats_by_ids(prev_ids, new_ids, disconnect_proc, connect_proc, bulk_connect)
    common = prev_ids & new_ids unless prev_ids.nil? || new_ids.nil?
    unless common.nil?
      prev_ids -= common
      new_ids -= common
    end

    unless prev_ids.nil? || disconnect_proc.nil?
      prev_ids.each do |p|
        begin
          disconnect_proc.call(p)
        rescue => err
          _log.error("An error occurred while disconnecting id [#{p}]: #{err}")
          _log.log_backtrace(err)
        end
      end
    end

    unless new_ids.nil?
      if bulk_connect
        begin
          bulk_connect.call(new_ids)
        rescue => err
          _log.error("EMS: [#{@ems.name}], id: [#{@ems.id}] An error occurred while connecting ids [#{new_ids.join(',')}]: #{err}")
          _log.log_backtrace(err)
        end
      elsif connect_proc
        new_ids.each do |n|
          begin
            connect_proc.call(n)
          rescue => err
            _log.error("EMS: [#{@ems.name}], id: [#{@ems.id}] An error occurred while connecting id [#{n}]: #{err}")
            _log.log_backtrace(err)
          end
        end
      end
    end
  end
end
