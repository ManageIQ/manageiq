# Generic mixin module that supports assignment by CI of management tags

module AssignmentMixin
  extend ActiveSupport::Concern
  ESCAPED_PREFIX = "escaped".freeze
  NAMESPACE_SUFFIX = "assigned_to".freeze

  def all_assignments(tag = nil)
    scope = Tag.where(["name LIKE ?", "%/#{AssignmentMixin::NAMESPACE_SUFFIX}/%"])
    scope = scope.where(["name LIKE ?", "%#{tag}"]) if tag.present?

    scope
  end
  module_function :all_assignments

  included do  #:nodoc:
    acts_as_miq_taggable

    const_set("ASSIGNMENT_PARENT_ASSOCIATIONS", %i(parent_blue_folders parent_resource_pool host ems_cluster ext_management_system my_enterprise physical_server)) unless const_defined?("ASSIGNMENT_PARENT_ASSOCIATIONS")

    cache_with_timeout(:assignments_cached, 1.minute) { assignments }
  end

  def assign_to_objects(objects, klass = nil)
    # objects => A single item or array of items
    #   item  => A CI instance (not classification) or a CI id of klass
    # klass   => The class of the object that self is to be assigned to - (Takes both forms - Host or host, EmsCluster or ems_cluster)
    objects.to_miq_a.each do |obj|
      tag = build_object_tag_path(obj, klass)
      tag_add(tag, :ns => namespace)
    end
    reload
  end

  def unassign_objects(objects, klass = nil)
    # objects => A single item or array of items
    #   item  => A CI instance (not classification) or a CI id of klass
    # klass   => The class of the object that self is to be unassigned from - (Takes both forms - Host or host, EmsCluster or ems_cluster)
    objects.to_miq_a.each do |obj|
      tag = build_object_tag_path(obj, klass)
      tag_remove(tag, :ns => namespace)
    end
    reload
  end

  def assign_to_tags(objects, klass)
    # objects => A single item or array of items
    #   item  => A classification entry instance or a classification entry id
    # klass   => The class of the object that self is to be assigned to - (Takes both forms - Host or host, EmsCluster or ems_cluster)
    objects.to_miq_a.each do |obj|
      tag = build_tag_tagging_path(obj, klass)
      next if tag.nil?
      tag_add(tag, :ns => namespace)
    end
    reload
  end

  def unassign_tags(objects, klass)
    objects.to_miq_a.each do |obj|
      tag = build_tag_tagging_path(obj, klass)
      next if tag.nil?
      tag_remove(tag, :ns => namespace)
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
        obj = CustomAttribute.find_by(:id => id)
        if obj.nil?
          _log.warn("Unable to find label with id [#{id}], skipping assignment")
          next
        end
      end
      name = AssignmentMixin.escape(obj.name)
      value = AssignmentMixin.escape(obj.value)
      tag = "#{klass.underscore}/label/managed/#{name}/#{value}"
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
        object = model.find_by(:id => parts.pop) unless model.nil?
        result[:objects] << object unless object.nil?
      when :tag
        tag = Tag.find_by(:name => "/" + parts.join("/"))
        classification = Classification.find_by(:tag_id => tag.id) if tag
        result[:tags] << [classification, klass] if classification
      when :label
        label = if AssignmentMixin.escaped?(parts[1])
                  name = AssignmentMixin.unescape(parts[1])
                  value = AssignmentMixin.unescape(parts[2])
                  CustomAttribute.find_by(:name => name, :value => value)
                else
                  CustomAttribute.find_by(:name => parts[1], :value => parts[2])
                end
        result[:labels] << [label, klass] unless label.nil?
      end
    end

    result
  end

  # make strings with special characters like '/' safe to put in tags(assignments) by escaping them
  def self.escape(string)
    @parser ||= URI::RFC2396_Parser.new
    escaped_string = @parser.escape(string, /[^A-Za-z0-9]/)
    "#{ESCAPED_PREFIX}:{#{escaped_string}}" # '/escape/string' --> 'escaped:{%2Fescape%2Fstring}'
  end

  # return the escaped string back into a normal string
  def self.unescape(escaped_string)
    _log.info("not an escaped string: #{escaped_string}") unless escaped?(escaped_string)
    @parser ||= URI::RFC2396_Parser.new
    @parser.unescape(escaped_string.slice(ESCAPED_PREFIX.length + 2..-2)) # 'escaped:{%2Fescape%2Fstring}' --> '/escape/string'
  end

  def self.escaped?(string)
    string.starts_with?("#{ESCAPED_PREFIX}:{") && string.ends_with?("}")
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

    def tag_class(klass)
      klass == "VmOrTemplate" ? "vm" : klass.underscore
    end

    # @param target
    # @option options :parents
    # @option options :tag_list
    def get_assigned_for_target(target, options = {})
      _log.debug("Input for get_assigned_for_target id: #{target.id} class: #{target.class}") if target
      if options[:parents]
        parents = options[:parents]
        _log.debug("Parents are passed from parameter")
      else
        _log.debug("Parents are not passed from parameter")
        parents = self::ASSIGNMENT_PARENT_ASSOCIATIONS.flat_map do |rel|
          (rel == :my_enterprise ? MiqEnterprise.my_enterprise : target.try(rel)) || []
        end
        parents << target
      end

      parents.each { |parent| _log.debug("parent id: #{parent.id} class: #{parent.class}") } if parents.kind_of?(Array)

      tlist =  parents.collect { |p| "#{p.class.base_model.name.underscore}/id/#{p.id}" } # Assigned directly to parents
      if options[:tag_list] # Assigned to target (passed in)
        tlist += options[:tag_list]
        _log.debug("Using tag list: #{options[:tag_list].join(', ')}")
      end

      _log.debug("Directly assigned to parents: #{tlist.join(', ')}")

      individually_assigned_resources = tlist.flat_map { |t| assignments_cached[t] }.uniq

      _log.debug("Individually assigned resources: #{individually_assigned_resources.map { |x| "id:#{x.id} class:#{x.class}" }.join(', ')}")

      # look for alert_set running off of tags (not individual tags)
      # TODO: we may need to change taggings-related code to use base_model too
      tlist = Tagging.where("tags.name like '/managed/%'")
                     .where(:taggable => parents)
                     .references(:tag).includes(:tag).map do |t|
        "#{tag_class(t.taggable_type)}/tag#{t.tag.name}"
      end

      _log.debug("Tags assigned to parents: #{tlist.join(', ')}")
      tagged_resources = tlist.flat_map { |t| assignments_cached[t] }.uniq

      _log.debug("Tagged resources: #{individually_assigned_resources.map { |x| "id:#{x.id} class:#{x.class}" }.join(', ')}")
      (individually_assigned_resources + tagged_resources).uniq
    end

    def namespace
      "/#{base_model.name.underscore}/#{NAMESPACE_SUFFIX}"
    end
  end # module ClassMethods

  private

  def build_object_tag_path(obj, klass = nil)
    if obj.kind_of?(ActiveRecord::Base) # obj is a CI
      "#{obj.class.base_model.name.underscore}/id/#{obj.id}"
    else                                # obj is the id of an instance of <klass>
      raise _("Class must be specified when object is an integer") if klass.nil?
      "#{klass.underscore}/id/#{obj}"
    end
  end

  def build_tag_tagging_path(obj, klass)
    unless obj.kind_of?(ActiveRecord::Base) # obj is the id of a classification entry instance
      id = obj
      obj = Classification.find_by(:id => id)
      if obj.nil?
        _log.warn("Unable to find classification with id [#{id}], skipping assignment")
        return nil
      end
    end
    "#{klass.underscore}/tag#{obj.ns}/#{obj.parent.name}/#{obj.name}"
  end
end # module AssignmentMixin
