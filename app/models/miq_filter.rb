module MiqFilter
  ALLOWED_DESCENDANT_CLASSES_FROM_MODEL = %w[ExtManagementSystem].freeze

  def self.belongsto2object(tag)
    belongsto2object_list(tag).last
  end

  def self.belongsto2path_human(tag)
    tag.split("/").map { |x| x.split("|").second }.compact.join(" -> ")
  end

  def self.find_descendant_class_by(klass, name)
    if ALLOWED_DESCENDANT_CLASSES_FROM_MODEL.include?(klass.to_s) && (descendant_class = klass.try(:belongsto_descendant_class, name))
      return descendant_class.constantize
    else
      _log.warn("Unable to find descendant class for belongsto filter: #{klass}/#{name}")
    end

    nil
  end

  def self.find_object_by_special_class(klass, name)
    if (descendant_class = find_descendant_class_by(klass, name)) && descendant_class.respond_to?(:find_object_for_belongs_to_filter)
      return descendant_class.find_object_for_belongs_to_filter(name)
    else
      _log.warn("#{klass} is not supported for loading objects of descendants classes.(belongsto filter: #{klass}/#{name}, descendant class: #{descendant_class}")
    end

    nil
  end

  def self.find_object_by_name(klass, name)
    klass = klass.constantize
    object = klass.find_by(:name => name)
    if object.nil?
      find_object_by_special_class(klass, name)
    else
      object
    end
  end

  def self.belongsto2object_list(tag)
    # /belongsto/ExtManagementSystem|<name>/EmsCluster|<name>/EmsFolder|<name>
    raise _("invalid tag: %{tag}") % {:tag => tag} unless tag.starts_with?("/belongsto/ExtManagementSystem")

    parts = tag.split("/")[2..-1]
    depth = parts.size - 1 # ancestry uses 0 based depth

    # Get the root EMS object
    # TODO: For tree queries deeper than 1, we don't actually need the ems object,
    #       so find a way to just get the id
    ems_class, ems_name = parts.first.split("|", 2)
    ems = find_object_by_name(ems_class, ems_name)

    if ems.nil?
      _log.warn("lookup for klass=#{ems_class.to_s.inspect} with name=#{ems_name.inspect} failed in tag=#{tag.inspect}")
      return []
    end

    return [ems] if depth == 0

    # Get the leaf node object for this EMS
    leaf_class, leaf_name = parts.last.split("|", 2)
    leaves = leaf_class.constantize
      .includes(:all_relationships)
      .where(:name => leaf_name, :ems_id => ems.id)

    # If multiple leaves come back, filter by depth, and then find which one has
    #   the valid path. It's possible multiple leaves could be at the same depth.
    leaves.each do |leaf|
      next unless leaf.depth == depth

      # Get the full path from the leaf object to the root
      result = leaf.with_relationship_type("ems_metadata") { leaf.path }

      # Verify that the records match what's in the provided tag
      result_parts = result&.map { |o| "#{o.class.base_model.name}|#{o.name}" }
      return result if result_parts == parts
    end

    # Nothing was found from any of the candidates
    _log.warn("lookup failed for tag=#{tag.inspect}")
    []
  end

  def self.object2belongsto(obj)
    # /belongsto/ExtManagementSystem|<name>/EmsCluster|<name>/EmsFolder|<name>
    unless obj.root_id[0] == "ExtManagementSystem"
      raise _("Folder Root is not a Provider")
    end

    tag = obj.relationship_ancestry(
      :field_delimiter  => '|',
      :record_delimiter => '/',
      :include_self     => true,
      :field_method     => :name
    )
    "/belongsto/#{tag}"
  end

  def self.apply_belongsto_filters(inputs, bfilters)
    return []     if inputs.nil?
    return inputs if bfilters.empty?

    vcmeta_index = bfilters.index_with { |tag| belongsto2object_list(tag) }

    filtered = []
    inputs.each do |p|
      bfilters.each do |tag|
        vcmeta_list = vcmeta_index[tag]

        if p.kind_of?(Storage)
          vcmeta_list.reverse_each do |vcmeta|
            if vcmeta.respond_to?(:storages) && vcmeta.storages.include?(p)
              filtered.push(p)
              break
            end
          end
          break if filtered.last == p
        else
          vcmeta_list = vcmeta_list[0..-2] if vcmeta_list.last.kind_of?(Host)
          vcmeta = vcmeta_list.last

          next if vcmeta.nil?

          if vcmeta == p || vcmeta.with_relationship_type("ems_metadata") { vcmeta.is_ancestor_of?(p) }
            filtered.push(p)
            break
          end
        end
      end
    end

    filtered
  end
end
