module MiqFilter
  def self.records2table(records, only_columns)
    MiqReportable.records2table(records, only_columns)
  end

  def self.determine_mode_for_find_children_of(reflection, obj, assoc)
    mode = nil
    if reflection.nil? || reflection.macro == :has_and_belongs_to_many
      if obj.respond_to?(assoc)
        mode = :by_method
      else
        raise "no relationship found for \"#{assoc}\"" if reflection.nil?
      end
    else
      mode = :by_reflection
    end

    mode
  end

  def self.find_children_of_via_reflection(obj, reflection)
    result = obj.send(reflection.name)
    if reflection.macro == :has_one || reflection.macro == :belongs_to
      result ? [result] : []
    else
      result
    end
  end

  def self.find_children_of_via_method(obj, assoc)
    obj.send(assoc)
  end

  def self.find_children_of(obj, assoc)
    reflection = obj.class.reflect_on_association(assoc.to_sym)
    mode       = determine_mode_for_find_children_of(reflection, obj, assoc)

    case mode
    when :by_reflection  then find_children_of_via_reflection(obj, reflection)
    when :by_method      then find_children_of_via_method(obj, assoc)
    else                      raise _("Unknown mode: <%{mode}>") % {:mode => mode.inspect}
    end
  end

  def self.belongsto2object(tag)
    belongsto2object_list(tag).last
  end

  def self.belongsto2object_list(tag)
    # /belongsto/ExtManagementSystem|<name>/EmsCluster|<name>/EmsFolder|<name>
    raise _("invalid tag: %{tag}") % {:tag => tag} unless tag.starts_with?("/belongsto/ExtManagementSystem")
    parts = tag.split("/")
    2.times { parts.shift }

    r = parts.shift
    klass, name = r.split("|")
    klass = klass.constantize
    obj = klass.find_by_name(name)

    if obj.nil?
      _log.warn("lookup for klass=#{klass.to_s.inspect} with name=#{name.inspect} failed in tag=#{tag.inspect}")
      return []
    end

    result = [obj]
    parts.each do |p|
      tag_part_klass, name = p.split("|")
      tag_part_klass = tag_part_klass.constantize

      match = nil

      obj.with_relationship_type('ems_metadata') do
        obj.children.each do |c|
          if c.kind_of?(tag_part_klass) && c.name == name
            match = c
            break
          end
        end
      end

      return result unless match
      obj = match
      result.push(obj)
    end
    result
  end

  def self.object2belongsto(obj)
    # /belongsto/ExtManagementSystem|<name>/EmsCluster|<name>/EmsFolder|<name>
    unless obj.root_id[0] == "ExtManagementSystem"
      raise _("Folder Root is not a %{table}") % {:table => ui_lookup(:table => "ext_management_systems")}
    end

    tag = obj.ancestry(
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
