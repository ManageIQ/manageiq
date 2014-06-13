module ServiceMixin
  extend ActiveSupport::Concern

  included do
    # These relationships are used for resources that are processed as part of the service
    has_many   :service_resources, :order => "group_idx ASC", :dependent => :destroy
    has_many   :resource_actions, :as => :resource, :dependent => :destroy

    serialize  :options, Hash

    include UuidMixin
    include OwnershipMixin
    include ReportableMixin
    acts_as_miq_taggable

  end

  def add_resource(rsc, options={})
    rsc_type = rsc.class.base_class.name.tableize
    raise "Cannot connect service with nil ID." if rsc.id.nil? && rsc_type == "service_templates"

    sr = self.service_resources.detect{|sr| sr.resource_type == rsc.class.base_class.name && sr.resource_id == rsc.id}
    if sr.nil?
      if options.kind_of?(ServiceResource)
        nh = options.attributes.dup
        %W{id created_at updated_at service_template_id service_id}.each {|key| nh.delete(key)}
      else
        nh = options
      end

      if self.is_circular_reference?(rsc)
        raise MiqException::MiqServiceCircularReferenceError, "Adding resource <#{rsc.name}> to Service <#{self.name}> will create a circular reference"
      else
        sr = self.service_resources.new(nh.merge(:resource => rsc))
        self.set_service_type if self.respond_to?(:set_service_type)
        # Create link between services
        self.services << rsc if self.class == Service && rsc.class == Service
      end
    end
    return sr
  end
  alias << add_resource

  def add_resource!(rsc, options={})
    sr = self.add_resource(rsc, options)
    self.save!
    sr
  end

  def remove_resource(rsc)
    sr = self.service_resources.find(:first, :conditions => {:resource_type => rsc.class.base_class.name, :resource_id => rsc.id})
    sr.try(:destroy)
  end

  def remove_all_resources
    self.service_resources.destroy_all
  end

  def max_group_delay(grp_idx, delay_type)
    result = 0
    self.each_group_resource(grp_idx) {|r| result = [result, r[delay_type] || self.class::DEFAULT_PROCESS_DELAY_BETWEEN_GROUPS].max}
    result
  end

  def delay_for_action(grp_idx, action)
    delay_type = :start_delay if action == :start
    delay_type = :stop_delay if action == :stop
    self.max_group_delay(grp_idx, delay_type)
  end

  def each_group_resource(grp_idx=nil)
    if grp_idx.nil?
      self.service_resources.each do |sr|
        yield(sr)
      end
    else
      self.service_resources.each do |sr|
        yield(sr) if sr.group_idx == grp_idx
      end
    end
  end

  def group_has_resources?(grp_idx)
    self.each_group_resource(grp_idx) {|sr| return true}
    return false
  end

  def last_group_index
    last_idx = 0
    self.service_resources.each {|sr| last_idx = [last_idx, sr.group_idx].max}
    return last_idx
  end

  def next_group_index(current_idx, direction=1)
    last_idx = self.last_group_index
    method, target = direction > 0 ? [:upto, last_idx] : [:downto, 0]

    (current_idx+direction).send(method, target) do |i|
      next if i == current_idx
      return(i) if self.group_has_resources?(i)
    end

    return nil
  end

  def compact_group_indexes
    # Remove empty group
    last_idx = self.last_group_index
    return if last_idx == 0

    last_idx.downto(0) do |idx|
      self.each_group_resource {|r| r.group_idx -= 1 if r.group_idx >= idx} unless self.group_has_resources?(idx)
    end
  end

  def is_circular_reference?(child_svc)
    circular_reference_check(child_svc).nil? ? false : true
  end

  def circular_reference_check(child_svc, parent_svc=self)
    return child_svc if child_svc == parent_svc
    return nil unless child_svc.kind_of?(Service) || child_svc.kind_of?(ServiceTemplate)
    self.parent_services(parent_svc).each do |service|
      return(service) if service.id == child_svc.id
      result = circular_reference_check(child_svc, service)
      return(result) unless result.nil?
    end
    nil
  end

  def parent_services(svc=self)
    srs = ServiceResource.where(:resource_type => svc.class.name, :resource_id => svc.id)
    svc = srs.collect {|sr| service = sr.send(sr.resource_type.underscore)}.compact
  end

  def sub_services(options={})
    klass = self.class
    result = self.service_resources.collect do |s|
      svcs = []
      if s.resource.kind_of?(klass)
        svcs << s.resource
        if options[:recursive] == true
          svcs << s.resource.sub_services(options)
        end
      end
      svcs
    end

    result.compact.flatten
  end
end
