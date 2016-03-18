# Generic mixin module that supports assignment by CI of management tags

module AssignmentMixin
  extend ActiveSupport::Concern
  included do  #:nodoc:
    acts_as_miq_taggable

    const_set("ASSIGNMENT_PARENT_ASSOCIATIONS", [:parent_blue_folders, :parent_resource_pool, :host, :ems_cluster, :ext_management_system, :my_enterprise]) unless const_defined?("ASSIGNMENT_PARENT_ASSOCIATIONS")

    cache_with_timeout(:assignments_cached, 1.minute) { assignments }
  end

  def assign_to_objects(objects, klass = nil)
    # objects => A single item or array of items
    #   item  => A CI instance (not classification) or a CI id of klass
    # klass   => The class of the object that self is to be assigned to - (Takes both forms - Host or host, EmsCluster or ems_cluster)
    objects.to_miq_a.each do |obj|
      if obj.kind_of?(ActiveRecord::Base) # obj is a CI
        tag = "#{obj.class.base_model.name.underscore}/id/#{obj.id}"
      else                                # obj is the id of an instance of <klass>
        raise _("Class must be specified when object is an integer") if klass.nil?
        tag = "#{klass.underscore}/id/#{obj}"
      end
      tag_add(tag, :ns => namespace)
    end
    reload
  end

  def assign_to_tags(objects, klass)
    # objects => A single item or array of items
    #   item  => A classification entry instance or a classification entry id
    # klass   => The class of the object that self is to be assigned to - (Takes both forms - Host or host, EmsCluster or ems_cluster)
    objects.to_miq_a.each do |obj|
      unless obj.kind_of?(ActiveRecord::Base) # obj is the id of a classification entry instance
        id = obj
        obj = Classification.find_by_id(id)
        if obj.nil?
          _log.warn("Unable to find classification with id [#{id}], skipping assignment")
          next
        end
      end
      tag = "#{klass.underscore}/tag#{obj.ns}/#{obj.parent.name}/#{obj.name}"
      tag_add(tag, :ns => namespace)
    end
    reload
  end

  def get_assigned_tos
    # Returns: {:objects => [obj, obj, ...], :tags => [[Classification.entry_object, klass], ...]}
    result = {:objects => [], :tags => []}
    tags = tag_list(:ns => namespace).split
    tags.each do |t|
      parts = t.split("/")
      klass = parts.shift
      type  = parts.shift
      case type.to_sym
      when :id
        model  = Object.const_get(klass.camelize) rescue nil
        object = model.find_by_id(parts.pop) unless model.nil?
        result[:objects] << object unless object.nil?
      when :tag
        tag = Tag.find_by_name("/" + parts.join("/"))
        result[:tags] << [Classification.find_by_tag_id(tag.id), klass] unless tag.nil?
      end
    end

    result
  end

  def remove_all_assigned_tos(cat = nil)
    # Optional cat arg can be as much of the tail portion (after /miq_alert/assigned_to/) as desired
    # Example: If Tags = "/miq_alert/assigned_to/host/tag/managed/environment/prod" and
    #                    "/miq_alert/assigned_to/host/id/4"
    # => cat = "host" will remove all the host assignments - both host/id/n and host/tag/...
    # => cat = "host/tag" will remove only the host tag assignments.
    # => cat = nil will remove all assignments from object
    tag_with("", :ns => namespace, :cat => cat)
    reload
  end

  delegate :namespace, :to => :class

  module ClassMethods
    def assignments
      # Get all assigned, enabled instances for type klass
      records = kind_of?(Class) ? all : self
      assignment_map = records.each_with_object({}) { |a, h| h[a.id] = a }
      Tag
        .where("taggings.taggable_type = ? and tags.name like ?", name, "#{namespace}/%")
        .joins(:taggings)
        .each_with_object([]) do |tag, arr|
          tag.taggings.each do |tagging|
            next unless assignment_map[tagging.taggable_id]
            arr << {
              :assigned    => assignment_map[tagging.taggable_id],
              :assigned_to => Tag.filter_ns([tag], namespace).first
            }
          end
        end
    end

    def get_assigned_for_target(target, options = {})
      # options = {
      #   :parents      => TODO
      #   :tag_list     => TODO
      # }
      alist = kind_of?(Class) ? assignments_cached : assignments
      if options[:parents]
        parents = options[:parents]
      else
        model = kind_of?(Class) ? self : model
        parents = model::ASSIGNMENT_PARENT_ASSOCIATIONS.each_with_object([]) do |rel, arr|
          t = rel == :my_enterprise ? MiqEnterprise : target
          next unless t.respond_to?(rel)
          arr << t.send(rel)
        end.flatten.compact
        parents << target
      end

      tlist =  parents.collect { |p| "#{p.class.base_model.name.underscore}/id/#{p.id}" } # Assigned directly to parents
      tlist += options[:tag_list] if options[:tag_list]                        # Assigned to target (passed in)

      if options[:associations_preloaded]
        # Collect tags directly from association from parent objects if they were already preloaded by the caller
        tags = parents.collect { |p| p.tags.select { |t| t.name.starts_with?("/managed/") } }.flatten.uniq
      else
        # Collect tags from all parent objects in a single query if they were NOT already preloaded by the caller
        tcond = []; targs = []
        parents.each do |p|
          tcond << "(taggings.taggable_type=? AND taggings.taggable_id=?)"
          # TODO: we may need to change taggings-related code to use base_model too
          targs << p.class.base_class.name << p.id
        end
        cond = ["(#{tcond.join(" OR ")}) AND (name like '/managed/%')", *targs]
        tags = Tag.where(cond).joins(:taggings)
      end
      # Assigned to parent tags
      # TODO: we may need to change taggings-related code to use base_model too
      parent_ids_by_type = parents.inject({}) { |h, p|  h[p.class.base_class.name] ||= []; h[p.class.base_class.name] << p.id; h }
      tlist += tags.inject([]) do |arr, tag|
        tag.taggings.each do |t|
          # Only collect taggings for parent objects
          klass = t.taggable_type
          if parent_ids_by_type[klass] && parent_ids_by_type[klass].include?(t.taggable_id)
            if klass == "VmOrTemplate"       # right now NO support for tagged templates
              arr << "vm/tag#{tag.name}"
            else
              arr << "#{klass.underscore}/tag#{tag.name}"
            end
          end
        end
        arr
      end

      result = alist.inject([]) do |arr, a|
        arr << a[:assigned] if tlist.include?(a[:assigned_to])
        arr
      end

      result.uniq
    end

    def namespace
      "/#{base_model.name.underscore}/assigned_to"
    end
  end # module ClassMethods
end # module AssignmentMixin
