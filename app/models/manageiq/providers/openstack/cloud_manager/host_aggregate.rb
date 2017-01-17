class ManageIQ::Providers::Openstack::CloudManager::HostAggregate < ::HostAggregate

  supports :update_aggregate
  supports :delete_aggregate
  supports :add_host
  supports :remove_host

  store :metadata, :accessors => [:availability_zone]

  # if availability zone named in metadata exists, return it
  def availability_zone_obj
    AvailabilityZone.find_by(:ems_ref => availability_zone, :ems_id => ems_id)
  end

  def self.create_aggregate_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => "ManageIQ::Providers::Openstack::CloudManager::HostAggregate",
      :method_name => 'create_aggregate',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_aggregate(ems_id, options)
    raise ArgumentError, _("ems cannot be nil") if ems_id.nil?
    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ems cannot be found") if ext_management_system.nil?

    create_args = {:name => options[:name]}
    unless options[:availability_zone].blank?
      create_args[:availability_zone] = options[:availability_zone]
    end
    aggregate = nil
    metadata = {}

    connection_options = {:service => "Compute"}
    ext_management_system.with_provider_connection(connection_options) do |service|
      aggregate = service.aggregates.create(create_args)
      if aggregate.availability_zone
        metadata[:availability_zone] = aggregate.availability_zone
      end
    end
    create!(:name                  => options[:name],
            :ems_ref               => aggregate.id,
            :metadata              => metadata,
            :ext_management_system => ext_management_system)
  rescue => e
    _log.error "host_aggregate=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqHostAggregateCreateError, e.to_s, e.backtrace
  end

  def external_aggregate
    connection_options = { :service => "Compute" }
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.aggregates.get(ems_ref)
    end
  end

  def update_aggregate_queue(userid, options = {})
    task_opts = {
      :action => "updating Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_aggregate',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_aggregate(options)
    unless options[:name].blank?
      rename_aggregate(options[:name])
    end

    unless options[:metadata].blank?
      update_aggregate_metadata(options[:metadata])
    end
  end

  def rename_aggregate(new_name)
    aggr = external_aggregate
    if aggr.name != new_name
      aggr.name = new_name
      aggr.update
    end
  rescue => e
    _log.error "host_aggregate=[#{name}], error: #{e}"
    raise MiqException::MiqHostAggregateUpdateError, e.to_s, e.backtrace
  end

  def update_aggregate_metadata(new_metadata)
    aggr = external_aggregate
    out_metadata = aggr.metadata.each_with_object({}) { |(k, _v), outp| outp[k] = nil }
    # Host Aggregate metadata comes from fog with string keys rather than symbols,
    # make sure input metadata has string keys here.
    out_metadata.merge!(new_metadata.stringify_keys)
    aggr.update_metadata(out_metadata)
  rescue => e
    _log.error "host_aggregate=[#{name}], error: #{e}"
    raise MiqException::MiqHostAggregateUpdateError, e.to_s, e.backtrace
  end

  def delete_aggregate_queue(userid)
    task_opts = {
      :action => "deleting Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_aggregate',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_aggregate
    external_aggregate.destroy
  rescue => e
    _log.error "host_aggregate=[#{name}], error: #{e}"
    raise MiqException::MiqHostAggregateDeleteError, e.to_s, e.backtrace
  end

  def external_host_list
    connection_options = {:service => "Compute"}
    ext_management_system.with_provider_connection(connection_options, &:hosts)
  end

  def find_external_hostname(new_host)
    return nil unless new_host
    external_host_list.find do |h|
      h.host_name.split(".").first == new_host.hypervisor_hostname
    end.try(:host_name)
  end

  def add_host_queue(userid, new_host)
    task_opts = {
      :action => "Adding Host to Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'add_host',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [new_host.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def add_host(host_id)
    raise ArgumentError, _("Host ID cannot be nil") if host_id.nil?
    new_host = Host.find(host_id)
    raise ArgumentError, _("Host cannot be found") if new_host.nil?

    unless (hostname = find_external_hostname(new_host)).blank?
      external_aggregate.add_host(hostname)
    end
  rescue => e
    _log.error "host_aggregate=[#{name}], error: #{e}"
    raise MiqException::MiqHostAggregateAddHostError, e.to_s, e.backtrace
  end

  def remove_host_queue(userid, old_host)
    task_opts = {
      :action => "Removing Host from Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'remove_host',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [old_host.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def remove_host(host_id)
    raise ArgumentError, _("Host ID cannot be nil") if host_id.nil?
    old_host = Host.find(host_id)
    raise ArgumentError, _("Host cannot be found") if old_host.nil?

    unless (hostname = find_external_hostname(old_host)).blank?
      external_aggregate.remove_host(hostname)
    end
  rescue => e
    _log.error "host_aggregate=[#{name}], error: #{e}"
    raise MiqException::MiqHostAggregateRemoveHostError, e.to_s, e.backtrace
  end
end
