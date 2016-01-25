module EmsRefresh::SaveInventoryContainer
  DEFAULT_FIND_KEY = [:ems_ref]
  ALWAYS_IGNORED = [:namespace]
  # Each element in ROOT_ITEMS corresponds to one in-coming hash in save_ems_container_inventory
  ROOT_ITEMS = [
    :container_projects, :container_quotas, :container_limits, :container_nodes, :container_builds,
    :container_build_pods, :container_image_registries, :container_images, :container_replicators, :container_groups,
    :container_services, :container_routes, :persistent_volumes, :container_component_statuses
  ]
  # Describes haw each element should be saved.
  # Children: Nested entities, included inside their parent Hash. These correspond to another DESCRIPTOR item.
  # Links:    Related entities previously inserted into the current hash, handled by LINKS.
  # find key: These determine if an incoming items should update an existing saved entity or add a new one.
  DESCRIPTOR = {
    :container_project             => {
      :children => :labels,
    },
    :label                         => {
      :find_key => [:section, :name]
    },
    :container_quota               => {
      :links    => :container_project,
      :children => :container_quota_items,
    },
    :container_quota_item          => {
      :find_key => :resource
    },
    :container_limit               => {
      :links    => :container_project,
      :children => :container_limit_items
    },
    :container_limit_item          => {
      :find_key => [:resource, :item_type]
    },
    :container_node                => {
      :children => [:labels, :computer_system, :container_conditions]
    },
    :computer_system               => {
      :children => [:hardware, :operating_system]
    },
    :container_condition           => {
      :find_key => :name
    },
    :container_build               => {
      :links    => :container_project,
      :children => :labels
    },
    :container_build_pod           => {
      :links    => :container_build,
      :children => :labels
    },
    :container_image_registry      => {
      :find_key => [:host, :port]
    },
    :container_image               => {
      :find_key => [:image_ref, :container_image_registry_id],
      :links    => :container_image_registry
    },
    :container_replicator          => {
      :links    => [:container_project],
      :children => [:labels, :selector_parts]
    },
    :container_group               => {
      :children => [:container_definitions, :containers, :labels, :node_selector_parts, :container_conditions,
                    :container_volumes],
      :links    => [:container_node, :container_replicator, :container_project, :container_build_pod]
    },
    :container_definition          => {
      :children => [:container_port_configs, :container_env_vars, :security_context, :container]
    },
    :container_port_config         => {

    },
    :container_env_var             => {
      :find_key => [:name, :value, :field_path]
    },
    :security_context              => {},
    :container                     => {
      :links    => :container_image
    },
    :node_selector_part            => {
      :find_key => [:section, :name]
    },
    :container_volume              => {
      :find_key => :name
    },
    :container_service             => {
      :links    => [:container_groups, :container_project, :container_image_registry],
      :children => [:labels, :selector_parts, :container_service_port_configs]
    },
    :selector_part                 => {
      :find_key => [:section, :name]
    },
    :container_service_port_config => {},
    :container_route               => {
      :links    => [:container_project, :container_service],
      :children => :labels
    },
    :persistent_volume             => {},
    :container_component_status    => {
      :find_key => :name
    },
  }
  LINKS = {
    :container_project        => ->(h, _) { h[:container_project_id] = h.fetch_path(:container_project, :id) },
    :container_service        => ->(h, _) { h[:container_service_id] = h.fetch_path(:container_service, :id) },
    :container_groups         => ->(h, _) { h[:container_group_ids] = h[:container_groups].map { |x| x[:id] } },
    :container_node           => ->(h, _) { h[:container_node_id] = h.fetch_path(:container_node, :id) },
    :container_replicator     => ->(h, _) { h[:container_replicator_id] = h.fetch_path(:container_replicator, :id) },
    :container_image          => ->(h, _) { h[:container_image_id] = h[:container_image][:id] unless h.nil? },
    :container_image_registry => lambda { |h, _|
      h[:container_image_registry_id] = h.fetch_path(:container_image_registry, :id)
    },
    :container_build          => ->(h, _) { h[:container_build_id] = h.fetch_path(:container_build, :id) },
    :container_build_pod      => lambda { |h, ems|
      ems.container_build_pods.find_by_name(h[:build_pod_name]).try(:id)
      h.delete(:build_pod_name)
    }
  }

  def save_ems_container_inventory(ems, hashes, target = nil)
    ROOT_ITEMS.each do |entities|
      send("save_#{entities}_inventory", ems, hashes[entities], target)
    end

    ems.save!
  end

  def method_missing(method_sym, *arguments, &block)
    if (m = method_sym.to_s.match(/^save_(?<obj>.*)_inventory$/)) && DESCRIPTOR[m['obj'].singularize.to_sym]
      singularize = m['obj'].singularize
      find_key, links, children = get_item singularize.to_sym
      if singularize == m['obj']
        save_single_inventory(m['obj'], links, children, *arguments)
      else
        save_multiple_inventory(m['obj'], find_key, links, children, *arguments)
      end
    else
      super
    end
  end

  def get_item(item)
    desc = DESCRIPTOR[item]
    [
      Array.wrap((desc[:find_key] || DEFAULT_FIND_KEY)),
      Array.wrap(desc[:links]),
      Array.wrap(desc[:children]),
    ]
  end

  def save_multiple_inventory(item, find_key, links, children, parent, hashes, target = nil)
    unless hashes.nil?
      target = parent if target.nil? && parent.kind_of?(ExtManagementSystem)
      previous_entities = parent.send(item, true)
      deletes = target.kind_of?(ExtManagementSystem) ? previous_entities.dup : []
      links.each do |linked_key|
        hashes.each do |h|
          LINKS[linked_key].call(h, parent)
        end
      end
      save_inventory_multi(parent.send(item), hashes, deletes, find_key, children, links + ALWAYS_IGNORED)
      store_ids_for_new_records(parent.send(item), hashes, find_key)
    end
  end

  def save_single_inventory(item, links, children, parent, hash)
    links.each do |linked_key|
      LINKS[linked_key].call(hash, parent)
    end
    save_inventory_single(item, parent, hash, children, links + ALWAYS_IGNORED)
  end
end
