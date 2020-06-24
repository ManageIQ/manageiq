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

    # root object
    klass, name = parts.shift.split("|")
    obj = find_object_by_name(klass, name)

    if obj.nil?
      _log.warn("lookup for klass=#{klass.to_s.inspect} with name=#{name.inspect} failed in tag=#{tag.inspect}")
      return []
    end

    # traverse the tree
    parts.each_with_object([obj]) do |p, result|
      tag_part_klass, name = p.split("|")
      tag_part_klass = tag_part_klass.constantize

      obj = obj.with_relationship_type('ems_metadata') do
        obj.children.grep(tag_part_klass).detect { |c| c.name == name }
      end

      return [] unless obj
      result.push(obj)
    end
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

    filtered = []
    inputs.each do |p|
      bfilters.each do |tag|
        if p.kind_of?(Storage)
          vcmeta_list = belongsto2object_list(tag)
          vcmeta_list.reverse_each do |vcmeta|
            if vcmeta.respond_to?(:storages) && vcmeta.storages.include?(p)
              filtered.push(p)
              break
            end
          end
          break if filtered.last == p
        else
          vcmeta_list = belongsto2object_list(tag)
          vcmeta_list.pop if vcmeta_list.last.kind_of?(Host)
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
