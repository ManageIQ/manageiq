module MiqFilter
  def self.records2table(records, options)
    MiqReportable.records2table(records, options)
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

  def self.find_children_of_via_reflection(obj, reflection, options = {})
    db = reflection.class_name.constantize
    if db.respond_to?(:find_filtered)
      if reflection.macro == :belongs_to
        objid = obj.send(reflection.foreign_key)
        return [[], 0] if objid.nil?

        conditions = "id = #{objid}"
      else
        conditions = "#{reflection.foreign_key} = #{obj.id}"
      end
      conditions += " AND (#{reflection.options[:conditions]})" if reflection.options[:conditions]
      options.delete(:include)
      options.delete(:includes)
      result, total_count = db.find_filtered(:all, options.merge(:conditions => conditions))
    else
      options.delete(:tag_filters)
      if reflection.macro == :has_one
        result = [obj.send(reflection.name)]
      else
        result = obj.send(reflection.name).find(:all,
          :order      => options[:order],
          :offset     => options[:offset],
          :limit      => options[:limit],
          :conditions => options[:conditions]
        )
      end
      total_count = result.length
    end

    return result, total_count
  end

  def self.find_children_of_via_method(obj, assoc, options = {})
    db = obj.class
    unfiltered = obj.send(assoc)
    if db.respond_to?(:find_filtered)
      if options[:tag_filters]
        mfilters = options[:tag_filters]["managed"]
        bfilters = options[:tag_filters]["belongsto"]
      end
      mfilters ||= []
      bfilters ||= []
      result = unfiltered.collect do |r|
        next unless r.is_tagged_with_grouping?(mfilters, :ns => "*")
        next unless self.apply_belongsto_filters([r], bfilters) == [r]
        r
      end.compact
    else
      result = unfiltered
    end

    total_count = unfiltered.length

    # Need to honor order
    if options[:order]
      col, direction = options[:order].split
      direction ||= "ASC"
      result.sort! { |x,y| x.send(col) <=> y.send(col) }
      result.reverse! if direction == "DESC"
    end

    # Need to honor limit and offset
    if options[:limit]
      options[:offset] ||= 0
      result = result[options[:offset]..options[:offset] + options[:limit] - 1]
    end

    return result, total_count
  end

  def self.find_children_of(obj, assoc, options = {})
    reflection = obj.class.reflect_on_association(assoc.to_sym)
    mode       = determine_mode_for_find_children_of(reflection, obj, assoc)

    case mode
    when :by_reflection  then find_children_of_via_reflection(obj, reflection, options)
    when :by_method      then find_children_of_via_method(obj, assoc, options)
    else                      raise "Unknown mode: <#{mode.inspect}>"
    end
  end

  def self.count_children_of(obj, assoc, options = {})
    result = find_children_of(obj, assoc, options).first
    return result ? result.length : 0
  end

  def self.belongsto2object(tag)
    self.belongsto2object_list(tag).last
  end

  def self.belongsto2object_list(tag)
    #/belongsto/ExtManagementSystem|<name>/EmsCluster|<name>/EmsFolder|<name>
    raise "invalid tag: #{tag}" unless tag.starts_with?("/belongsto/ExtManagementSystem")
    parts = tag.split("/")
    2.times {parts.shift}

    r = parts.shift
    klass, name = r.split("|")
    obj = klass.constantize.find_by_name(name)

    if obj.nil?
      $log.warn("MIQ(MiqFilter.belongsto2object_list) lookup for klass=#{klass.inspect} with name=#{name.inspect} failed in tag=#{tag.inspect}")
      return []
    end

    result = [obj]
    parts.each do |p|
      klass, name = p.split("|")
      match = nil

      obj.with_relationship_type('ems_metadata') do
        obj.children.each do |c|
          if c.class.to_s == klass && c.name == name
            match = c
            break
          end
        end
      end

      return result unless match
      obj = match
      result.push(obj)
    end
    return result
  end

  def self.object2belongsto(obj)
    #/belongsto/ExtManagementSystem|<name>/EmsCluster|<name>/EmsFolder|<name>
    raise "Folder Root is not a #{ui_lookup(:table => "ext_management_systems")}" unless obj.root_id[0] == "ExtManagementSystem"

    tag = obj.ancestry(
      :field_delimiter  => '|',
      :record_delimiter => '/',
      :include_self     => true,
      :field_method     => :name
    )
    return "/belongsto/#{tag}"
  end

  def self.apply_belongsto_filters(inputs, bfilters)
    return []     if inputs.nil?
    return inputs if bfilters.empty?

    filtered = []
    inputs.each do |p|
      bfilters.each do |tag|
        if p.kind_of?(Storage)
          vcmeta_list = self.belongsto2object_list(tag)
          vcmeta_list.reverse.each do |vcmeta|
            if vcmeta.respond_to?(:storages) && vcmeta.storages.include?(p)
              filtered.push(p)
              break
            end
          end
          break if filtered.last == p
        else
          vcmeta = self.belongsto2object(tag)
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
