class CustomButton < ActiveRecord::Base
  default_scope :conditions => self.conditions_for_my_region_default_scope
  has_one       :resource_action, :as => :resource, :dependent => :destroy, :autosave => true

  serialize :options
  serialize :applies_to_exp
  serialize :visibility

  validates :applies_to_class, :presence => true
  validates :name, :description, :uniqueness => {:scope => [:applies_to_class, :applies_to_id]}, :presence => true
  validates :guid, :uniqueness => true, :presence => true

  include UuidMixin
  acts_as_miq_set_member

  BUTTON_CLASSES = %w{ Vm Host ExtManagementSystem Storage EmsCluster MiqTemplate Service ServiceTemplate}

  def self.buttons_for(other, applies_to_id=nil)
    if other.kind_of?(Class)
      applies_to_class = other.base_model.name
      applies_to_id    = applies_to_id
    elsif other.kind_of?(String)
      applies_to_class = other
      applies_to_id    = applies_to_id
    else
      raise "Instance has no id" if other.id.nil?
      applies_to_class = other.class.base_model.name
      applies_to_id    = other.id
    end

    where(:applies_to_class => applies_to_class, :applies_to_id => applies_to_id)
  end

  def applies_to
    klass = self.applies_to_class.constantize
    self.applies_to_id.nil? ? klass : klass.find_by_id(self.applies_to_id)
  end

  def applies_to=(other)
    if other.kind_of?(Class)
      self.applies_to_class = other.base_model.name
      self.applies_to_id    = nil
    elsif other.kind_of?(String)
      self.applies_to_class = other
      self.applies_to_id    = nil
    else
      raise "Instance has no id" if other.id.nil?
      self.applies_to_class = other.class.base_model.name
      self.applies_to_id    = other.id
    end
  end

  def invoke(target)
    args = self.resource_action.automate_queue_hash({:object_type => target.class.base_class.name, :object_id => target.id})
    args[:user_id] ||= User.current_user.try(:id)
    zone = target.respond_to?(:my_zone) ? target.my_zone : nil
    MiqQueue.put(
      :class_name  => 'MiqAeEngine',
      :method_name => 'deliver',
      :args        => [args],
      :role        => 'automate',
      :zone        => zone,
      :priority    => MiqQueue::HIGH_PRIORITY,
    )
  end

  def self.save_as_button(opts)
    [:uri, :userid, :target_attr_name].each {|a| raise "no value given for '#{a}'" if opts[a].nil?}

    opts[:options] = {:target_attr_name => opts.delete(:target_attr_name)}
    opts[:uri_path], opts[:uri_attributes], opts[:uri_message] = self.parse_uri(opts.delete(:uri))

    rec = self.new(opts)
    if opts[:description].nil? && !rec.new_record?
      rec.destroy
      return nil
    end

    rec.new_record? ? rec.save! : rec.update_attributes!(opts)
    return rec
  end

  def to_export_xml(_options)
  end

  # Helper methods to support moving automate columns to resource_actions table
  def uri=(value)
  end

  def uri
    self.resource_action.try(:ae_uri)
  end

  def uri_path=(value)
    ra = self.get_resource_action
    ra.ae_namespace, ra.ae_class, ra.ae_instance, attr_name = MiqAeEngine::MiqAePath.split(value)
  end

  def uri_path
    self.get_resource_action.try(:ae_path)
  end

  def uri_message=(value)
    self.get_resource_action.ae_message = value
  end

  def uri_message
    self.get_resource_action.ae_message
  end

  def uri_attributes=(value)
    attrs = value.reject { |k,v| MiqAeEngine::DEFAULT_ATTRIBUTES.include?(k) }
    self.get_resource_action.ae_attributes = attrs
  end

  def uri_attributes
    self.get_resource_action.ae_attributes
  end

  def uri_object_name
    self.get_resource_action.ae_instance
  end

  def get_resource_action
    return self.resource_action unless self.resource_action.nil?
    self.build_resource_action()
  end
  # End - Helper methods to support moving automate columns to resource_actions table

  def self.parse_uri(uri)
    scheme, userinfo, host, port, registry, path, opaque, query, fragment = MiqAeEngine::MiqAeUri.split(uri)
    return path, MiqAeEngine::MiqAeUri.query2hash(query), fragment
  end

  def self.button_classes
    return BUTTON_CLASSES
  end

  def self.available_for_user(user,group)
    user = self.get_user(user)
    role = user.miq_user_role_name || user.role.name
    # Return all automation uri's that has his role or is allowed for all roles.
    self.all.to_a.select do |uri|
      uri.parent && uri.parent.name == group && uri.visibility.has_key?(:roles) && (uri.visibility[:roles].include?(role) || uri.visibility[:roles].include?("_ALL_"))
    end
  end

  def self.get_user(user)
    user = User.in_region.find_by_userid(user) if user.kind_of?(String)
    raise "Unable to find user '#{user}'" if user.nil?
    return user
  end

end
