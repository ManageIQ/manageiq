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

  def assign_to_labels(objects, klass)
    # objects => A single item or array of items
    #   item  => A classification entry instance or a classification entry id
    # klass   => The class of the object that self is to be assigned to - (Takes both forms - Host or host, EmsCluster or ems_cluster)
    objects.to_miq_a.each do |obj|
      unless obj.kind_of?(ActiveRecord::Base) # obj is the id of a classification entry instance
        id = obj
        obj = CustomAttribute.find_by_id(id)
        if obj.nil?
          _log.warn("Unable to find label with id [#{id}], skipping assignment")
          next
        end
      end
      tag = "#{klass.underscore}/label/managed/#{obj.name}/#{obj.value}"
      tag_add(tag, :ns => namespace)
    end
    reload
  end

  def get_assigned_tos
    # Returns: {:objects => [obj, obj, ...], :tags => [[Classification.entry_object, klass], ...]}
    result = {:objects => [], :tags => [], :labels => []}
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
      when :label
        label = CustomAttribute.find_by(:name => parts[1], :value => parts[2])
        result[:labels] << [label, klass] unless label.nil?
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
    # get a mapping of alert_sets and the tags they are assigned
    #
    # the namespace is removed from the front of the objects tag. e.g.:
    #   If alert_set will have:
    #     alert_set.tag.name == "/miq_alert_set/assigned_to/vm/tag/managed/environment/test"
    #   assignments will return
    #     {assigned: alert_set, assigned_to: "vm/tag/managed/environment/test"}
    #   and will match:
    #     vm.tag.name = "/managed/environment/test"
    def assignments
      # Get all assigned, enabled instances for type klass
      records = kind_of?(Class) ? all : self
      assignment_map = records.each_with_object({}) { |a, h| h[a.id] = a }
      Tag
        .includes(:taggings).references(:taggings)
        .where("taggings.taggable_type = ? and tags.name like ?", name, "#{namespace}/%")
        .each_with_object(Hash.new { |h, k| h[k] = [] }) do |tag, ret|
          tag.taggings.each do |tagging|
            tag_name = Tag.filter_ns([tag], namespace).first
            taggable = assignment_map[tagging.taggable_id]
            ret[tag_name] << taggable if taggable
          end
        end
    end

    # @param target
    # @option options :parents
    # @option options :tag_list
    def get_assigned_for_target(target, options = {})
      if options[:parents]
        parents = options[:parents]
      else
        parents = self::ASSIGNMENT_PARENT_ASSOCIATIONS.flat_map do |rel|
          (rel == :my_enterprise ? MiqEnterprise.my_enterprise : target.try(rel)) || []
        end
        parents << target
      end

      tlist =  parents.collect { |p| "#{p.class.base_model.name.underscore}/id/#{p.id}" } # Assigned directly to parents
      tlist += options[:tag_list] if options[:tag_list]                        # Assigned to target (passed in)

      individually_assigned_resources = tlist.flat_map { |t| assignments_cached[t] }.uniq

      # look for alert_set running off of tags (not individual tags)
      # TODO: we may need to change taggings-related code to use base_model too
      tlist = Tagging.where("tags.name like '/managed/%'")
                     .where(:taggable => parents)
                     .references(:tag).includes(:tag).map do |t|
        klass = t.taggable_type
        lower_klass = klass == "VmOrTemplate" ? "vm" : klass.underscore
        "#{lower_klass}/tag#{t.tag.name}"
      end
      tagged_resources = tlist.flat_map { |t| assignments_cached[t] }.uniq
      (individually_assigned_resources + tagged_resources).uniq
    end

    def namespace
      "/#{base_model.name.underscore}/assigned_to"
    end
  end # module ClassMethods
end # module AssignmentMixin
