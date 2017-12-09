class OvirtInventory
  attr_accessor :service

  def initialize(options = {})
    @service = Ovirt::Service.new(options)
  end

  def api
    standard_collection('api').first
  end

  def capabilities
    standard_collection("capabilities")
  end

  def clusters
    standard_collection("clusters")
  end

  def datacenters
    standard_collection("datacenters", "data_center")
  end

  def domains
    standard_collection("domains")
  end

  def events(options = {})
    if options[:since]
      standard_collection("events?from=#{options[:since]}", "event")
    elsif options[:max]
      standard_collection("events;max=#{options[:max]}", "event", false, "time", :desc)
    else
      standard_collection("events")
    end
  end

  def groups
    standard_collection("groups")
  end

  def hosts
    standard_collection("hosts", nil, true)
  end

  def networks
    standard_collection("networks")
  end

  def roles
    standard_collection("roles")
  end

  def storagedomains
    standard_collection("storagedomains", "storage_domain", true)
  end

  def tags
    standard_collection("tags")
  end

  def templates
    standard_collection("templates")
  end

  def users
    standard_collection("users")
  end

  def vms
    standard_collection("vms", nil, true)
  end

  def vmpools
    standard_collection("vmpools")
  end

  def get_vm(path)
    vm_guid = ::File.basename(path, '.*')
    vm      = get_resource_by_ems_ref("/api/vms/#{vm_guid}") rescue nil
    vm      = get_resource_by_ems_ref("/api/templates/#{vm_guid}") if vm.blank?
    vm
  end

  def get_resource_by_ems_ref(uri_suffix, element_name = nil)
    @service.get_resource_by_ems_ref(uri_suffix, element_name)
  end

  def get_resources_by_uri_path(uri_suffix, element_name = nil, xpath = nil)
    @service.get_resources_by_uri_path(uri_suffix, element_name, xpath)
  end

  def refresh
    # TODO: Change to not return native objects to the caller.  The caller
    #       should just expect raw data.
    primary_items = collect_primary_jobs(primary_item_jobs)
    collect_secondary_items(primary_items, SECONDARY_ITEMS)
  end

  def targeted_refresh(methods)
    primary_items = collect_primary_targeted_jobs(methods[:primary].to_a)
    collect_secondary_items(primary_items, methods[:secondary])
  end

  def api_path
    @service.api_path
  end

  private

  def standard_collection(uri_suffix, element_name = nil, paginate = false, sort_by = :name, direction = :asc)
    @service.standard_collection(uri_suffix, element_name, paginate, sort_by, direction)
  end

  # TODO: Remove this key/method translation and just use the method name as
  #       the key directly.
  PRIMARY_ITEMS = {
    # Key          RHEVM API method
    :cluster    => :clusters,
    :vmpool     => :vmpools,
    :network    => :networks,
    :storage    => :storagedomains,
    :datacenter => :datacenters,
    :host       => :hosts,
    :vm         => :vms,
    :template   => :templates
  }

  SECONDARY_ITEMS = {
    # Key          RHEVM API methods
    :datacenter => [:storagedomains],
    :host       => [:statistics, :host_nics], # :cdroms, tags
    :vm         => [:disks, :snapshots, :nics],
    :template   => [:disks]
  }

  def primary_item_jobs
    PRIMARY_ITEMS.to_a
  end

  # Returns all combinations of primary resources and the methods to run on those resources.
  #
  # > secondary_item_jobs({:vm, => [v1, v2]})
  #  => [[v1, :disks], [v1, :snapshots], [v1, :nics], [v2, :disks], [v2, :snapshots], [v2, :nics]]
  def secondary_item_jobs(primary_items, secondary_items)
    secondary_items.flat_map do |key, methods|
      primary_items[key].product(methods)
    end
  end

  def collect_primary_jobs(jobs)
    results = collect_in_parallel(jobs) do |_, method|
      send(method)
    end

    jobs.zip(results).each_with_object({}) do |((key, _), result), hash|
      hash[key] = result
    end
  end

  def collect_primary_targeted_jobs(jobs)
    results = collect_in_parallel(jobs) do |key, ems_ref|
      xpath = key == :host ? '/host' : nil
      if ems_ref.kind_of?(Array)
        ems_ref.flat_map { |item| get_resources_by_uri_path(item, nil, xpath) rescue Array.new }
      elsif ems_ref.kind_of?(Hash)
        collection, element_name = ems_ref.first
        standard_collection(collection, element_name, true)
      else
        get_resources_by_uri_path(ems_ref, nil, xpath) rescue Array.new
      end
    end

    jobs.zip(results).each_with_object({}) do |((key, _), result), hash|
      hash[key] = result
    end
  end

  def collect_secondary_items(primary_items, secondary_items)
    jobs = secondary_item_jobs(primary_items, secondary_items)

    results = collect_in_parallel(jobs) do |resource, method|
      resource.send(method) rescue nil
    end

    jobs.zip(results).each do |(resource, method), result|
      resource.attributes[method] = result
    end

    primary_items
  end

  def collect_in_parallel(jobs, &block)
    require 'parallel'
    Parallel.map(jobs, :in_threads => num_threads, &block)
  end

  def num_threads
    use_threads? ? 8 : 0
  end

  # HACK: VCR is not threadsafe, and so tests running under VCR fail
  def use_threads?
    !defined?(VCR)
  end
end
