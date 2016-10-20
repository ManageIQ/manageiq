module ServiceMixin
  extend ActiveSupport::Concern

  included do
    # These relationships are used for resources that are processed as part of the service
    has_many   :service_resources, -> { order "group_idx ASC" }, :dependent => :destroy
    has_many   :resource_actions, :as => :resource, :dependent => :destroy

    serialize  :options, Hash

    include UuidMixin
    include OwnershipMixin
    acts_as_miq_taggable
  end

  def add_resource(rsc, options = {})
    rsc_type = rsc.class.base_class.name.tableize
    raise _("Cannot connect service with nil ID.") if rsc.id.nil? && rsc_type == "service_templates"

    # fetch the corresponding service resource
    # may want to use a query for this
    sr = service_resources.detect { |sr| sr.resource_type == rsc.class.base_class.name && sr.resource_id == rsc.id }
    if sr.nil?
      if options.kind_of?(ServiceResource)
        nh = options.attributes.dup
        %w(id created_at updated_at service_template_id ancestry).each { |key| nh.delete(key) }
      else
        nh = options
      end

      if circular_reference?(rsc)
        raise MiqException::MiqServiceCircularReferenceError,
              _("Adding resource <%{resource_name}> to Service <%{name}> will create a circular reference") %
                {:resource_name => rsc.name, :name => name}
      else
        sr = service_resources.new(nh.merge(:resource => rsc))
        set_service_type if self.respond_to?(:set_service_type)
        # Create link between services
        rsc.update_attributes(:parent => self) if self.class == Service && rsc.class == Service
      end
    end
    sr
  end

  def <<(*args)
    add_resource(*args)
  end

  def add_resource!(rsc, options = {})
    sr = add_resource(rsc, options)
    self.save!
    sr
  end

  def remove_resource(rsc)
    sr = service_resources.find_by(:resource_type => rsc.class.base_class.name, :resource_id => rsc.id)
    sr.try(:destroy)
  end

  def remove_all_resources
    service_resources.destroy_all
  end

  def max_group_delay(grp_idx, delay_type)
    result = 0
    each_group_resource(grp_idx) { |r| result = [result, r[delay_type] || self.class::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS].max }
    result
  end

  def delay_for_action(grp_idx, action)
    max_group_delay(grp_idx, delay_type(action))
  end

  def combined_group_delay(action)
    group_idxs = service_resources.map(&:group_idx).uniq
    [].tap do |results|
      group_idxs.each { |idx| results << max_group_delay(idx, delay_type(action)) }
    end.sum
  end

  def delay_type(action)
    return :start_delay if action == :start
    return :stop_delay if action == :stop
  end

  def each_group_resource(grp_idx = nil)
    if grp_idx.nil?
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
    last_idx = 0
    service_resources.each { |sr| last_idx = [last_idx, sr.group_idx].max }
    last_idx
  end

  def next_group_index(current_idx, direction = 1)
    last_idx = last_group_index
    method, target = direction > 0 ? [:upto, last_idx] : [:downto, 0]

    (current_idx + direction).send(method, target) do |i|
      next if i == current_idx
      return(i) if self.group_has_resources?(i)
    end

    nil
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

  def parent_services(svc = self)
    return svc.ancestors if svc.kind_of?(Service)
    srs = ServiceResource.where(:resource => svc)
    srs.collect { |sr| sr.public_send(sr.resource_type.underscore) }.compact
  end
end
