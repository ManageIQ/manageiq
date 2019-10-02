module ServiceMixin
  extend ActiveSupport::Concern

  included do
    # These relationships are used for resources that are processed as part of the service
    has_many   :service_resources, -> { order("group_idx ASC") }, :dependent => :destroy
    has_many   :resource_actions, :as => :resource, :dependent => :destroy

    serialize  :options, Hash

    include UuidMixin
    acts_as_miq_taggable
  end

  def add_resource(rsc, options = {})
    rsc_type = rsc.class.base_class.name.tableize
    raise _("Cannot connect service with nil ID.") if rsc.id.nil? && rsc_type == "service_templates"

    enforce_single_service_parent(rsc)

    sr = service_resources.detect { |r| r.resource_type == rsc.class.base_class.name && r.resource_id == rsc.id }

    sr || create_service_resource(rsc, options)
  end

  def <<(*args)
    add_resource(*args)
  end

  def add_resource!(rsc, options = {})
    add_resource(rsc, options).tap { save! }
  end

  def remove_resource(rsc)
    service_resources.find_by(:resource_type => rsc.class.base_class.name, :resource_id => rsc.id).try(:destroy)
  end

  def remove_all_resources
    service_resources.destroy_all
  end

  def max_group_delay(grp_idx, delay_type)
    each_group_resource(grp_idx).collect { |r| r[delay_type] || self.class::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS }.max.to_i
  end

  def delay_for_action(grp_idx, action)
    max_group_delay(grp_idx, delay_type(action))
  end

  def combined_group_delay(action)
    service_resources.collect(&:group_idx).uniq.collect { |idx| max_group_delay(idx, delay_type(action)) }.sum
  end

  def delay_type(action)
    return :start_delay if action == :start
    return :stop_delay if action == :stop
  end

  def each_group_resource(grp_idx = nil)
    return enum_for(:each_group_resource) unless block_given?

    if children.present? && service_resources.empty?
      children.each do |child|
        child.service_resources.each { |sr| yield(sr) }
      end
    elsif grp_idx.nil?
      service_resources.each do |sr|
        yield(sr)
      end
    else
      service_resources.each do |sr|
        yield(sr) if sr.group_idx == grp_idx
      end
    end
  end

  def group_has_resources?(grp_idx)
    each_group_resource(grp_idx) { |_sr| return true }
    false
  end

  def last_group_index
    service_resources.collect(&:group_idx).max.to_i
  end

  def next_group_index(current_idx, direction = 1)
    last_idx = last_group_index
    method, target = direction > 0 ? [:upto, last_idx] : [:downto, 0]

    (current_idx + direction).send(method, target) do |i|
      next if i == current_idx
      return(i) if group_has_resources?(i)
    end

    nil
  end

  def parent_services(svc = self)
    return svc.ancestors if svc.kind_of?(Service)
    srs = ServiceResource.where(:resource => svc)
    srs.collect { |sr| sr.public_send(sr.resource_type.underscore) }.compact
  end

  private

  def enforce_single_service_parent(resource)
    if resource.try(:enforce_single_service_parent?) == true && resource.service
      raise MiqException::Error, _("<%{class_name}> <%{id}>:<%{name}> is already connected to a service.") %
                                 {:class_name => resource.class.name, :id => resource.id, :name => resource.name}
    end
  end

  def create_service_resource(rsc, options)
    if circular_reference?(rsc)
      raise MiqException::MiqServiceCircularReferenceError,
            _("Adding resource <%{resource_name}> to Service <%{name}> will create a circular reference") %
            {:resource_name => rsc.name, :name => name}
    else
      nh = if options.kind_of?(ServiceResource)
             options.attributes.except('id', 'created_at', 'updated_at', 'service_template_id', 'ancestry')
           else
             options
           end

      service_resources.new(nh.merge(:resource => rsc))
    end
  end

  def circular_reference?(child_svc)
    return true if child_svc == self
    if child_svc.kind_of?(Service)
      ancestor_ids.include?(child_svc.id)
    elsif child_svc.kind_of?(ServiceTemplate)
      !!circular_reference_check(child_svc)
    end
  end

  def circular_reference_check(child_svc, parent_svc = self)
    return child_svc if child_svc == parent_svc
    return nil unless child_svc.kind_of?(ServiceTemplate)
    parent_services(parent_svc).each do |service|
      return(service) if service.id == child_svc.id
      result = circular_reference_check(child_svc, service)
      return(result) unless result.nil?
    end
    nil
  end
end
