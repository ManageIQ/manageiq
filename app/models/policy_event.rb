class PolicyEvent < ApplicationRecord
  include_concern 'Purging'

  belongs_to  :miq_event_definition
  belongs_to  :miq_policy
  has_many    :contents,        :class_name => "PolicyEventContent", :dependent => :destroy

  virtual_has_many :miq_actions,     :uses => {:contents => :resource}
  virtual_has_many :miq_policy_sets, :uses => {:contents => :resource}

  def self.create_events(target, event, result)
    event = MiqEventDefinition.find_by(:name => event) if event.kind_of?(String)
    chain_id = nil
    result.each do |r|
      miq_policy_id = r[:miq_policy].id if r[:miq_policy].kind_of?(MiqPolicy) # handle built-in policies too
      pe = new(
        :event_type                       => event.name,
        :miq_event_definition_id          => event.id,
        :miq_event_definition_description => event.description,
        :timestamp                        => Time.now.utc,
        :miq_policy_id                    => miq_policy_id,
        :miq_policy_description           => r[:miq_policy].description,
        :result                           => r[:result].to_s,
        :target_id                        => target.id,
        :target_class                     => target.class.base_class.name,
        :target_name                      => target.name,
        :chain_id                         => chain_id
      # TODO: username,
      )

      pe.host_id = target.try(:host)&.id
      pe.ems_id = target.try(:ext_management_system)&.id
      pe.ems_cluster_id = target.try(:owning_cluster)&.id

      if chain_id.nil?
        pe.save
        chain_id = pe.id
        pe.chain_id = chain_id
      end

      (r[:miq_actions] + r[:miq_policy_sets]).each do |c|
        pe.contents << PolicyEventContent.new(:resource => c, :resource_description => c.description)
      end
      pe.save
    end
  end

  def miq_actions
    contents.collect { |c| c.resource if c.resource.kind_of?(MiqAction) }.compact
  end

  def miq_policy_sets
    contents.collect { |c| c.resource if c.resource.kind_of?(MiqPolicySet) }.compact
  end
end
