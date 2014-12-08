# TODO: Import/Export support

class MiqPolicy < ActiveRecord::Base
  default_scope { where self.conditions_for_my_region_default_scope }

  acts_as_miq_taggable
  acts_as_miq_set_member
  include_concern 'ImportExport'
  include ReportableMixin

  include UuidMixin
  include YAMLImportExportMixin
  before_validation :default_name_to_guid, :on => :create

  # NOTE: If another class references MiqPolicy through an ActiveRecord association,
  #   particularly has_one and belongs_to, calling .conditions will result in
  #   that method being directly called on the proxy object, as opposed to the
  #   target object, since that method is defined on the proxy object.  The
  #   workaround is to call .target on the proxy first before calling .conditions.
  #   Additionally, this reflection could be renamed to not cause a conflict.
  has_and_belongs_to_many :conditions

  has_many                :miq_policy_contents, :dependent => :destroy
  has_many                :policy_events

  virtual_has_many :miq_events, :uses => {:miq_policy_contents => :miq_event}

  validates_presence_of     :name, :description, :guid
  validates_uniqueness_of   :name, :description, :guid

  serialize :expression

  @@associations_to_get_policies = [:parent_enterprise, :ext_management_system, :parent_datacenter, :ems_cluster, :parent_resource_pool, :host]

  attr_accessor :reserved

  def description=(value)
    super(value ? value.truncate(MiqPolicy.columns_hash['description'].limit) : value)
  end

  # Note: Built-in policies only support one event and one action.
  @@built_in_policies = [
    {:name => "Stop Newly Retired Running VM",
      :description => "Stop Newly Retired Running VM",
      :towhat => "Vm",
      :event => "vm_retired",
      :applies_to? => true,
      :active => true,
      :condition => {"and"=>[{"="=>{"field"=>"Vm-retired", "value"=>true}}, {"="=>{"field"=>"Vm-power_state", "value"=>"on"}}]},
      :modifier => "deny",
      :mode => "control",
      :action => "vm_stop"},
    {:name => "Prevent Retired VM from Starting",
      :description => "Prevent Retired VM from starting",
      :towhat => "Vm",
      :event => "request_vm_start",
      :applies_to? => true,
      :active => true,
      :condition => {"="=>{"field"=>"Vm-retired", "value"=>true}},
      :modifier => "deny",
      :mode => "control",
      :action => "prevent"},
    {:name => "Stop Retired VM",
      :description => "Stop Retired VM",
      :towhat => "Vm",
      :event => "vm_start",
      :applies_to? => true,
      :active => true,
      :condition => {"="=>{"field"=>"Vm-retired", "value"=>true}},
      :modifier => "deny",
      :mode => "control",
      :action => "vm_stop"},
  ]
  @@built_ins = nil

  cattr_accessor :associations_to_get_policies

  def self.built_in_policies
    return @@built_ins.dup unless @@built_ins.nil?

    result = []
    @@built_in_policies.each {|bp|
      p = OpenStruct.new(bp)
      p.attributes = {"name" => "(Built-in) " + bp[:name], "description" => "(Built-in) " + bp[:description], :applies_to? => true}
      p.events = [MiqEvent.find_by_name(p.event)]
      p.conditions = []
      if p.condition
        p.conditions = [Condition.new(
            :name => p.attributes["name"],
            :description => p.attributes["description"],
            :expression => MiqExpression.new(p.condition),
            :modifier => p.modifier,
            :towhat => "Vm"
          )]
      end
      p.actions_for_event = [MiqAction.find_by_name(p.action)]
      result.push(p)
    }
    @@built_ins = result
    return @@built_ins.dup
  end

  CLEAN_ATTRS = ["id", "guid", "name", "created_on", "updated_on", "miq_policy_id"]
  def self.clean_attrs(attrs)
    CLEAN_ATTRS.each { |a| attrs.delete(a) }
    return attrs
  end

  def copy(new_fields)
    npolicy = self.class.new(self.class.clean_attrs(self.attributes).merge(new_fields))
    npolicy.conditions = self.conditions
    npolicy.miq_policy_contents = self.miq_policy_contents.collect do |pc|
      MiqPolicyContent.new(self.class.clean_attrs(pc.attributes))
    end
    npolicy.save!
    return npolicy
  end

  def miq_events
    self.miq_policy_contents.collect {|e| e.miq_event}.uniq
  end
  alias events miq_events

  def miq_actions
    self.miq_policy_contents.collect {|e| e.miq_action}.compact.uniq
  end
  alias actions miq_actions

  def actions_for_event(event, on=:failure)
    order = on == :success ? "success_sequence" : "failure_sequence"
    self.miq_policy_contents.find(:all, :conditions => ["miq_event_id = ?", event.id], :order => order).collect do |pe|
      next unless pe.qualifier == on.to_s
      pe.get_action(on)
    end.compact
  end

  def action_result_for_event(action,event)
    pe = miq_policy_contents.find_by_miq_action_id_and_miq_event_id(event.id, action.id)
    return pe.qualifier == "success"
  end

  def delete_event(event)
    MiqPolicyContent.destroy_all(["miq_policy_id = ? and miq_event_id = ?", self.id, event.id])
  end

  def add_event(event)
    MiqPolicyContent.create(:miq_policy_id => self.id, :miq_event_id => event.id)
  end

  def sync_events(events)
    cevents = self.miq_events
    adds = events - cevents
    deletes = cevents - events
    deletes.each { |e| self.delete_event(e) }
    adds.each    { |e| self.add_event(e) }
  end

  def replace_actions_for_event(event, action_list)
    self.delete_event(event)
    return if action_list.blank?

    succes_seq = 0
    fail_seq = 0
    action_list.each do |action, opts|
      opts[:qualifier] ||= "failure"
      opts[:sequence]  = opts[:qualifier].to_s == "success" ? succes_seq += 1 : fail_seq += 1
      add_action_for_event(event, action, opts)
    end
  end

  def self.enforce_policy(target, event, inputs={})
    return unless target.respond_to?(:get_policies)

    mode = event.ends_with?("compliance_check") ? "compliance" : "control"
    result = {:result => true, :details => []}

    # find event record
    unless event == "rsop" # rsop event doesn't exist. It's used to run rsop without taking any actions
      erec = MiqEvent.find_by_name(event)
      # raise "unable to find event named '#{event}'" if erec.nil?
      if erec.nil?
        self.logger.info("MIQ(policy-enforce_policy): Event: [#{event}], not defined, skipping policy enforcement")
        return result
      end
    end

    self.logger.info("MIQ(policy-enforce_policy): Event: [#{event}], To: [#{target.name}]")

    profiles, plist = get_policies_for_target(target, mode, event, inputs)
    return result if plist.blank?

    # evaluate conditions
    failed = []
    succeeded = []
    plist.each {|p|
      self.logger.info("MIQ(policy-enforce_policy): Resolving policy [#{p.description}]...")
      cond_result = "allow"
      if p.conditions.empty?
        succeeded.push(p)
        next
      end

      clist = []
      p.conditions.uniq.each {|c|
        # we'll hard code the "always" condition for now until we have full support for
        # defining actions for both successful and failed policies
        if c.name == "always"
          succeeded.push(p)
          next
        end

        unless c.applies_to?(target, inputs)
          # skip conditions that do not apply based on applies_to_exp
          self.logger.info("MIQ(policy-enforce_policy): Resolving policy [#{p.description}], Condition: [#{c.description}] does not apply, skipping...")
          next
        end

        eval_result = eval_condition(c, target, inputs)
        cond_result = eval_result if eval_result == "deny"
        clist.push(c.attributes.merge("result" => eval_result))

        break if eval_result == "deny" && mode == "control"
      }
      if cond_result == "deny"
        result[:result] = false
        result[:details].push(p.attributes.merge("result" => false, "conditions" => clist))
        failed.push(p)
      else
        result[:details].push(p.attributes.merge("result" => true, "conditions" => clist))
        succeeded.push(p)
      end
    }

    # inject policy results into errors attribute of "target" object
    target.errors.clear
    # TODO: If we need this validation on the object, create a real/virtual attribute so ActiveModel doesn't yell
    target.errors.add(:smart, result[:result])

    unless event == "rsop" # don't create policy events or invoke actions if we're doing rsop
      if mode == "control"
        pevent = self.build_results(failed, profiles, erec, :failure) + self.build_results(succeeded, profiles, erec, :success)
        PolicyEvent.create_events(target, event, pevent)
      end
      result[:actions] = MiqAction.invoke_actions(
        target,
        inputs.merge(:event => erec),
        succeeded,
        failed
      )
    end

    return result
  end

  def self.build_results(policies, profiles, event, status)
    # [
    #   :miq_policy => MiqPolicy#Object
    #   :result => ...,
    #   :miq_actions => [...],
    #   :miq_policy_sets => [...]
    # ]
    return policies.collect do |p|
      next unless p.kind_of?(self) # skip built-in policies
      {
        :miq_policy       => p,
        :result           => status.to_s,
        :miq_actions      => p.actions_for_event(event, status).uniq,
        :miq_policy_sets  => p.memberof.collect {|ps| ps if profiles.include?(ps)}.compact
      }
    end.compact
  end

  def self.resolve(rec, list=nil, event=nil)
    # list is expected to be a list of policies, not profiles.
    policies = list.nil? ? self.find(:all) : self.find_all_by_name(list)
    result = []
    policies.each {|p|
      next if event && !p.events.include?(event)

      policy_hash = {"result" => "allow", "conditions" => [], "actions" => []}
      policy_hash["scope"] = MiqExpression.evaluate_atoms(p.expression, rec) unless p.expression.nil?
      if policy_hash["scope"] && policy_hash["scope"]["result"] == false
        policy_hash["result"] = "N/A"
        result.push(p.attributes.merge(policy_hash))
        next
      end

      p.conditions.each {|c|
        next unless rec.class.base_model.to_s == c["towhat"]

        cond_hash = {"id" => c.id}
        cond_hash["scope"] = MiqExpression.evaluate_atoms(c.applies_to_exp, rec) unless c.applies_to_exp.nil?
        unless cond_hash["scope"] && cond_hash["scope"]["result"] == false
          cond_hash["result"] = eval_condition(c, rec)
          policy_hash["result"] = cond_hash["result"] if cond_hash["result"] == "deny"
          cond_hash["expression"] = MiqExpression.evaluate_atoms(c.expression, rec)
        else
          cond_hash["result"] = "N/A"
          cond_hash["expression"] = c.expression.exp
        end
        policy_hash["conditions"].push(cond_hash.merge(
          "name" => c.name,
          "description" => c.description
        ))
      }
      result_list = policy_hash["conditions"].collect {|c| c["result"]}.uniq
      policy_hash["result"] = result_list.first if result_list.length == 1 && result_list.first == "N/A"
      policy_hash["result"] = "N/A" unless p.active == true  # Ignore condition result if policy is inactive
      action_on = policy_hash["result"] == "deny" ? :failure : :success
      policy_hash["actions"] = p.actions_for_event(event, action_on).uniq.collect {|a|
        {"id" => a.id, "name" => a.name, "description" => a.description, "result" => policy_hash["result"]}
      } unless event.nil?
      result.push(p.attributes.merge(policy_hash))
    }
    result
  end

  def applies_to?(rec, inputs={})
    return false if !self.towhat.nil? && rec.class.base_model.name != self.towhat
    return true  if self.expression.nil?

    Condition.evaluate(self, rec, inputs)
  end

  def self.eval_condition(c, rec, inputs={})
    begin
      if Condition.evaluate(c, rec, inputs)
        result = c["modifier"]
      else
        if c["modifier"] == "deny"
          result = "allow"
        else
          result = "deny"
        end
      end
    rescue => err
      MiqPolicy.logger.log_backtrace(err)
    end
    result
  end

  EVENT_GROUPS_EXCLUDED = ["evm_operations", "ems_operations"]
  def self.all_policy_events
    MiqEvent.all_events.select {|e| !e.memberof.empty? && !EVENT_GROUPS_EXCLUDED.include?(e.memberof.first.name)}
  end

  def self.logger
    $policy_log
  end

  def last_event
    event = self.policy_events.last
    return event.nil? ? nil : event.created_on
  end

  def first_event
    event = self.policy_events.first
    return event.nil? ? nil : event.created_on
  end

  def first_and_last_event
    return [first_event, last_event].compact
  end

  def self.seed
    MiqRegion.my_region.lock do
      self.all.each do |p|
        attrs = {}
        attrs[:towhat] = "Vm"      if p.towhat.nil?
        attrs[:active] = true      if p.active.nil?
        attrs[:mode]   = "control" if p.mode.nil?
        if attrs.empty?
          $log.info("MIQ(MiqPolicy.seed) Updating [#{p.name}]")
          p.update_attributes(attrs)
        end
      end
    end
  end

  private

  def self.get_policies_for_target(target, mode, event, inputs = {})
    erec = MiqEvent.find_by_name(event)
    # collect policies expand profiles (sets)
    profiles = []
    plist = self.built_in_policies
    plist = plist.concat(target.get_policies.collect {|p|
      if p.is_a?(MiqPolicySet)
        profiles.push(p)
        p = p.members
      end
      p
    }.compact.flatten).uniq # get policies from target object
    @@associations_to_get_policies.each {|assoc|
      next unless target.respond_to?(assoc)

      obj = target.send(assoc)
      next unless obj
      plist = plist.concat(obj.get_policies.collect {|p|
        if p.is_a?(MiqPolicySet)
          profiles.push(p)
          p = p.members.sort{|a,b| a.name <=> b.name}
        end
        p
      }.compact.flatten).uniq
    }

    # Filter out policies that are not for the target class or the requested mode
    plist = plist.find_all { |p| p.mode == mode && p.towhat == target.class.base_model.name }

    # collect only policies that include event unless we're doing rsop
    plist.collect! {|p|
      if p.is_a?(MiqPolicy)
        # p if p.contains?(erec)
        p if p.events.include?(erec)
      else
        # built-in policies are OpenStructs
        p if p.events.include?(erec)
      end
    }.compact! unless event == "rsop"

    plist.collect! {|p|
      unless p.active == true
        self.logger.info("MIQ(policy-enforce_policy): Policy [#{p.description}] is not active, skipping...")
        next
      end

      applies = p.is_a?(MiqPolicy) ? p.applies_to?(target, inputs) : p.applies_to?
      unless applies
        self.logger.info("MIQ(policy-enforce_policy): Policy [#{p.description}] does not apply, skipping...")
        next
      end
      p
    }.compact!
    return profiles, plist
  end

  def add_action_for_event(event, action, opt_hash = nil)
    # we now expect an options hash provided by the UI, merge the qualifier with the options_hash
    # overwriting with the values from the options hash
    #    $log.debug("add_miq_action opt_hash: #{opt_hash.inspect}")
    opt_hash = {:qualifier => :failure}.merge(opt_hash)

    # update the correct DB sequence and synchronous value with the value from the UI
    opt_hash[:qualifier] = opt_hash[:qualifier].to_s
    case opt_hash[:qualifier]
    when "success"
      opt_hash[:success_sequence]    = opt_hash[:sequence]
      opt_hash[:success_synchronous] = opt_hash[:synchronous]
    when "failure"
      opt_hash[:failure_sequence]    = opt_hash[:sequence]
      opt_hash[:failure_synchronous] = opt_hash[:synchronous]
    when "both"
      opt_hash[:success_sequence]    = opt_hash[:sequence]
      opt_hash[:failure_sequence]    = opt_hash[:sequence]
      opt_hash[:success_synchronous] = opt_hash[:synchronous]
      opt_hash[:failure_synchronous] = opt_hash[:synchronous]
    end
    opt_hash.delete(:sequence)
    opt_hash.delete(:synchronous)

    pevent = self.miq_policy_contents.build(opt_hash)
    pevent.miq_event  = event
    pevent.miq_action = action
    pevent.save

    self.save!
  end
end
