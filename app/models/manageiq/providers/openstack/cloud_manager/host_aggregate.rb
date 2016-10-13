class ManageIQ::Providers::Openstack::CloudManager::HostAggregate < ::HostAggregate

  supports :update_aggregate
  supports :delete_aggregate
  supports :add_host
  supports :remove_host

  store :metadata, :accessors => [:availability_zone]

  # if availability zone named in metadata exists, return it
  def availability_zone_obj
    AvailabilityZone.find_by_ems_ref_and_ems_id(availability_zone, ems_id)
  end

  def self.create_aggregate(ext_management_system, options)
    raise ArgumentError, _("ext_management_system cannot be nil") if ext_management_system.nil?

    create_args = {:name => options[:name]}
    if options[:availability_zone]
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

  def update_aggregate(options)
    unless options[:name].blank?
      rename_aggregate(options[:name])
    end

    if options[:metadata]
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

  def add_host(new_host)
    unless (hostname = find_external_hostname(new_host)).blank?
      external_aggregate.add_host(hostname)
    end
  rescue => e
    _log.error "host_aggregate=[#{name}], error: #{e}"
    raise MiqException::MiqHostAggregateAddHostError, e.to_s, e.backtrace
  end

  def remove_host(old_host)
    unless (hostname = find_external_hostname(old_host)).blank?
      external_aggregate.remove_host(hostname)
    end
  rescue => e
    _log.error "host_aggregate=[#{name}], error: #{e}"
    raise MiqException::MiqHostAggregateRemoveHostError, e.to_s, e.backtrace
  end
end
