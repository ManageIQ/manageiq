class PolicyEvent < ActiveRecord::Base
  belongs_to  :miq_event
  belongs_to  :miq_policy
  has_many    :contents,        :class_name => "PolicyEventContent", :dependent => :destroy
  # has_many    :miq_actions,     :class_name => "PolicyEventContent", :conditions => "resource_type = 'MiqAction"
  # has_many    :miq_policy_sets, :class_name => "PolicyEventContent", :conditions => "resource_type = 'MiqPolicySet"

  include ReportableMixin

  virtual_has_many :miq_actions,     :uses => {:contents => :resource}
  virtual_has_many :miq_policy_sets, :uses => {:contents => :resource}

  def self.create_events(target, event, result)
    event = MiqEvent.find_by_name(event)
    chain_id = nil
    result.each do |r|
      miq_policy_id = r[:miq_policy].kind_of?(MiqPolicy) ? r[:miq_policy].id : nil # handle built-in policies too
      pe = self.new(
        :event_type               => event.name,
        :miq_event_id             => event.id,
        :miq_event_description    => event.description,
        :timestamp                => Time.now.utc,
        :miq_policy_id            => miq_policy_id,
        :miq_policy_description   => r[:miq_policy].description,
        :result                   => r[:result].to_s,
        :target_id                => target.id,
        :target_class             => target.class.base_class.name,
        :target_name              => target.name,
        :chain_id                 => chain_id
# TODO  :username,
      )

      pe.host_id = target.respond_to?(:host) && !target.host.nil? ? target.host.id : nil
      pe.ems_id = target.respond_to?(:ext_management_system) && !target.ext_management_system.nil? ? target.ext_management_system.id : nil
      pe.ems_cluster_id = target.respond_to?(:owning_cluster) && !target.owning_cluster.nil? ? target.owning_cluster.id : nil

      if chain_id.nil?
        pe.save
        chain_id = pe.id
        pe.chain_id = chain_id
      end

      (r[:miq_actions] + r[:miq_policy_sets]).each {|c|
        pe.contents << PolicyEventContent.new(:resource_id => c.id, :resource_type => c.class.name, :resource_description => c.description)
      }
      pe.save
    end
  end

  def miq_actions
    self.contents.collect {|c| c.resource if c.resource.kind_of?(MiqAction)}.compact
  end

  def miq_policy_sets
    self.contents.collect {|c| c.resource if c.resource.kind_of?(MiqPolicySet)}.compact
  end

end
