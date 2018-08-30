# TODO: Import/Export support

class MiqPolicy < ApplicationRecord
  acts_as_miq_taggable
  acts_as_miq_set_member
  include_concern 'ImportExport'

  include UuidMixin
  include YAMLImportExportMixin
  before_validation :default_name_to_guid, :on => :create

  default_value_for :towhat, 'Vm'
  default_value_for :active, true
  default_value_for :mode,   'control'

  # NOTE: If another class references MiqPolicy through an ActiveRecord association,
  #   particularly has_one and belongs_to, calling .conditions will result in
  #   that method being directly called on the proxy object, as opposed to the
  #   target object, since that method is defined on the proxy object.  The
  #   workaround is to call .target on the proxy first before calling .conditions.
  #   Additionally, this reflection could be renamed to not cause a conflict.
  has_and_belongs_to_many :conditions

  has_many                :miq_policy_contents, :dependent => :destroy
  has_many                :policy_events

  virtual_has_many :miq_event_definitions, :uses => {:miq_policy_contents => :miq_event_definition}

  validates_presence_of     :name, :description, :guid
  validates_uniqueness_of   :name, :description, :guid
  validates :mode, :inclusion => { :in => %w(compliance control) }

  scope :with_mode,   ->(mode)   { where(:mode => mode) }
  scope :with_towhat, ->(towhat) { where(:towhat => towhat) }

  serialize :expression

  @@associations_to_get_policies = [:parent_enterprise, :ext_management_system, :parent_datacenter, :ems_cluster, :parent_resource_pool, :host]

  attr_accessor :reserved

  cattr_accessor :associations_to_get_policies

  @@built_in_policies = nil

  def self.built_in_policies
    return @@built_in_policies.dup unless @@built_in_policies.nil?

    policy_hashes = YAML.load_file(Rails.root.join("product", "policy", "built_in_policies.yml"))

    @@built_in_policies = policy_hashes.collect do |p_hash|
      policy = OpenStruct.new(p_hash)
      policy.attributes =
        {
          "name"        => "(Built-in) #{p_hash[:name]}",
          "description" => "(Built-in) #{p_hash[:description]}",
          :applies_to?  => p_hash[:applies_to?]
        }
      policy.events = [MiqEventDefinition.find_by(:name => policy.event)]
      policy.conditions =
        if policy.condition
          [Condition.new(
            :name        => policy.attributes["name"],
            :description => policy.attributes["description"],
            :expression  => MiqExpression.new(policy.condition),
            :towhat      => "Vm"
          )]
        else
          []
        end
      policy.actions_for_event = [MiqAction.find_by(:name => policy.action)]

      p_metaclass = class << policy; self; end
      p_metaclass.send(:define_method, :applies_to?) { |*_args| p_hash[:applies_to?] }
      policy
    end
    @@built_in_policies.dup
  end

  CLEAN_ATTRS = %w(id guid name created_on updated_on miq_policy_id description)
  def self.clean_attrs(attrs)
    CLEAN_ATTRS.each { |a| attrs.delete(a) }
    attrs
  end

  def copy(new_fields)
    npolicy = self.class.new(self.class.clean_attrs(attributes).merge(new_fields))
    npolicy.conditions = conditions
    npolicy.miq_policy_contents = miq_policy_contents.collect do |pc|
      MiqPolicyContent.new(self.class.clean_attrs(pc.attributes))
    end
    npolicy.tap(&:save!)
  end

  def miq_event_definitions
    miq_policy_contents.collect(&:miq_event_definition).compact.uniq
  end
  alias_method :events, :miq_event_definitions

  def miq_actions
    miq_policy_contents.collect(&:miq_action).compact.uniq
  end
  alias_method :actions, :miq_actions

  def actions_for_event(event, on = :failure)
    order = on == :success ? "success_sequence" : "failure_sequence"
    miq_policy_contents.where(:miq_event_definition => event).order(order).collect do |pe|
      next unless pe.qualifier == on.to_s
      pe.get_action(on)
    end.compact
  end

  def delete_event(event)
    MiqPolicyContent.where(:miq_policy => self, :miq_event_definition => event).destroy_all
  end

  def add_event(event)
    MiqPolicyContent.create(:miq_policy => self, :miq_event_definition => event)
  end

  def sync_events(events)
    cevents = miq_event_definitions
    adds = events - cevents
    deletes = cevents - events
    deletes.each { |e| delete_event(e) }
    adds.each    { |e| add_event(e) }
  end

  def replace_actions_for_event(event, action_list)
    delete_event(event)
    return if action_list.blank?

    succes_seq = 0
    fail_seq = 0
    action_list.each do |action, opts|
      opts[:qualifier] ||= "failure"
      opts[:sequence]  = opts[:qualifier].to_s == "success" ? succes_seq += 1 : fail_seq += 1
      add_action_for_event(event, action, opts)
    end
  end

  def self.enforce_policy(target, event, inputs = {})
    return unless target.respond_to?(:get_policies)

    result = {:result => true, :details => []}

    erec = find_event_def(event)
    if erec.nil?
      logger.info("MIQ(policy-enforce_policy): Event: [#{event}], not defined, skipping policy enforcement")
      return result
    end

    logger.info("MIQ(policy-enforce_policy): Event: [#{event}], To: [#{target.name}]")

    mode = event.ends_with?("compliance_check") ? "compliance" : "control"

    profiles, plist = get_policies_for_target(target, mode, erec, inputs)
    return result if plist.blank?

    succeeded, failed = evaluate_conditions(plist, target, mode, inputs, result)

    # inject policy results into errors attribute of "target" object
    target.errors.clear
    # TODO: If we need this validation on the object, create a real/virtual attribute so ActiveModel doesn't yell
    target.errors.add(:smart, result[:result])

    actions = invoke_actions(target, mode, profiles, succeeded, failed, inputs.merge(:event => erec))
    result[:actions] = actions if actions
    result
  end

  def self.find_event_def(event)
    # rsop event doesn't exist. It's used to run rsop without taking any actions
    if event == 'rsop'
      MiqEventDefinition.new(:name => event)
    else
      MiqEventDefinition.find_by(:name => event)
    end
  end

  def self.display_name(number = 1)
    n_('Policy', 'Policies', number)
  end

  private_class_method :find_event_def

  def self.evaluate_conditions(plist, target, mode, inputs, result)
    failed = []
    succeeded = []
    plist.each do |p|
      logger.info("MIQ(policy-enforce_policy): Resolving policy [#{p.description}]...")
      if p.conditions.empty?
        always_condition = {"id" => nil, "description" => "always", "result" => "allow"}
        result[:details].push(p.attributes.merge("result" => true, "conditions" => [always_condition]))
        succeeded.push(p)
        next
      end

      cond_result, clist = evaluate_conditions_for_policy(target, p, mode, inputs)

      if cond_result == "deny"
        result[:result] = false
        result[:details].push(p.attributes.merge("result" => false, "conditions" => clist))
        failed.push(p)
      else
        result[:details].push(p.attributes.merge("result" => true, "conditions" => clist))
        succeeded.push(p)
      end
    end
    [succeeded, failed]
  end
  private_class_method :evaluate_conditions

  def self.evaluate_conditions_for_policy(target, policy, mode, inputs)
    cond_result = "allow"
    clist = []
    policy.conditions.uniq.each do |c|
      unless c.applies_to?(target, inputs)
        # skip conditions that do not apply based on applies_to_exp
        logger.info("MIQ(policy-enforce_policy): Resolving policy [#{policy.description}], Condition: [#{c.description}] does not apply, skipping...")
        next
      end

      eval_result = eval_condition(c, target, inputs)
      cond_result = eval_result if eval_result == "deny"
      clist.push(c.attributes.merge("result" => eval_result))

      break if eval_result == "deny" && mode == "control"
    end
    [cond_result, clist]
  end
  private_class_method :evaluate_conditions_for_policy

  def self.invoke_actions(target, mode, profiles, succeeded, failed, inputs)
    # don't create policy events or invoke actions if we're doing rsop
    event = inputs[:event]
    return if event.name == 'rsop'

    if mode == 'control'
      pevent = build_results(failed, profiles, event, :failure) + build_results(succeeded, profiles, event, :success)
      PolicyEvent.create_events(target, event, pevent)
    end
    MiqAction.invoke_actions(target, inputs, succeeded, failed)
  end
  private_class_method :invoke_actions

  def self.build_results(policies, profiles, event, status)
    # [
    #   :miq_policy => MiqPolicy#Object
    #   :result => ...,
    #   :miq_actions => [...],
    #   :miq_policy_sets => [...]
    # ]
    policies.collect do |p|
      next unless p.kind_of?(self) # skip built-in policies
      {
        :miq_policy      => p,
        :result          => status.to_s,
        :miq_actions     => p.actions_for_event(event, status).uniq,
        :miq_policy_sets => p.memberof.select { |ps| profiles.include?(ps) }
      }
    end.compact
  end
  private_class_method :build_results

  def self.resolve(rec, list = nil, event = nil)
    # list is expected to be a list of policies, not profiles.
    policies = list.nil? ? all : where(:name => list)
    policies.collect do |p|
      next if event && !p.events.include?(event)

      policy_hash = {"result" => "N/A", "conditions" => [], "actions" => []}
      policy_hash["scope"] = MiqExpression.evaluate_atoms(p.expression, rec) unless p.expression.nil?
      if policy_hash["scope"].nil? || policy_hash["scope"]["result"]
        policy_hash['result'], policy_hash['conditions'] = resolve_policy_conditions(p, rec)

        action_on = policy_hash["result"] == "deny" ? :failure : :success
        policy_hash["actions"] =
          p.actions_for_event(event, action_on).uniq.collect do |a|
            {"id" => a.id, "name" => a.name, "description" => a.description, "result" => policy_hash["result"]}
          end unless event.nil?
      end
      p.attributes.merge(policy_hash)
    end.compact
  end

  def self.resolve_policy_conditions(policy, rec)
    policy_result = 'allow'
    conditions =
      policy.conditions.collect do |c|
        rec_model = rec.class.base_model.name
        rec_model = "Vm" if rec_model.downcase.match("template")
        next unless rec_model == c["towhat"]

        resolve_condition(c, rec).tap do |cond_hash|
          policy_result = cond_hash["result"] if cond_hash["result"] == "deny"
        end
      end.compact

    if policy.active == true
      result_list = conditions.collect { |c| c["result"] }.uniq
      policy_result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
    else
      policy_result = "N/A" # Ignore condition result if policy is inactive
    end
    [policy_result, conditions]
  end
  private_class_method :resolve_policy_conditions

  def self.resolve_condition(cond, rec)
    cond_hash = {"id" => cond.id, "name" => cond.name, "description" => cond.description}
    cond_hash["scope"] = MiqExpression.evaluate_atoms(cond.applies_to_exp, rec) unless cond.applies_to_exp.nil?
    if cond_hash["scope"].nil? || cond_hash["scope"]["result"]
      cond_hash["result"] = eval_condition(cond, rec)
      cond_hash["expression"] = MiqExpression.evaluate_atoms(cond.expression, rec)
    else
      cond_hash["result"] = "N/A"
      cond_hash["expression"] = cond.expression.exp
    end
    cond_hash
  end
  private_class_method :resolve_condition

  def applies_to?(rec, inputs = {})
    rec_model = rec.class.base_model.name
    rec_model = "Vm" if rec_model.downcase.match("template")

    return false if towhat && rec_model != towhat
    return true  if expression.nil?

    Condition.evaluate(self, rec, inputs)
  end

  def self.eval_condition(c, rec, inputs = {})
    Condition.evaluate(c, rec, inputs) ? 'allow' : 'deny'
  rescue => err
    logger.log_backtrace(err)
  end
  private_class_method :eval_condition

  EVENT_GROUPS_EXCLUDED = ["evm_operations", "ems_operations"]
  def self.all_policy_events
    MiqEventDefinition.all_events.select { |e| !e.memberof.empty? && !EVENT_GROUPS_EXCLUDED.include?(e.memberof.first.name) }
  end

  def self.logger
    $policy_log
  end

  def last_event
    policy_events.last.try(:created_on)
  end

  def first_event
    policy_events.first.try(:created_on)
  end

  def first_and_last_event
    [first_event, last_event].compact
  end

  def self.get_policies_for_target(target, mode, event, inputs = {})
    event = find_event_def(event) if event.kind_of?(String)

    # collect policies expand profiles (sets)
    profiles, plist = get_expanded_profiles_and_policies(target)
    plist = built_in_policies.concat(plist).uniq

    towhat = target.class.base_model.name
    towhat = "Vm" if towhat.downcase.match("template")
    plist.keep_if do |p|
      p.mode == mode &&
      p.towhat == towhat &&
      policy_for_event?(p, event) &&
      policy_active?(p) &&
      policy_applicable?(p, target, inputs)
    end

    [profiles, plist]
  end

  def self.policy_for_event?(policy, event)
    event.name == 'rsop' || policy.events.include?(event)
  end
  private_class_method :policy_for_event?

  def self.policy_active?(policy)
    return true if policy.active

    logger.info("MIQ(policy-enforce_policy): Policy [#{policy.description}] is not active, skipping...")
    false
  end
  private_class_method :policy_active?

  def self.policy_applicable?(policy, target, inputs)
    return true if policy.applies_to?(target, inputs)

    logger.info("MIQ(policy-enforce_policy): Policy [#{policy.description}] does not apply, skipping...")
    false
  end
  private_class_method :policy_applicable?

  def self.get_expanded_profiles_and_policies(target)
    # get profiles and policies from target object
    target_policies = target.get_policies
    target_profiles = separate_profiles_from_policies(target_policies)

    # get profiles and policies from associations
    assoc_policies =
      @@associations_to_get_policies.collect do |assoc|
        next unless target.respond_to?(assoc)

        obj = target.send(assoc)
        next unless obj

        obj.get_policies
      end.compact.flatten
    assoc_profiles = separate_profiles_from_policies(assoc_policies)

    [target_profiles.concat(assoc_profiles), target_policies.concat(assoc_policies).flatten.compact.uniq]
  end
  private_class_method :get_expanded_profiles_and_policies

  def self.separate_profiles_from_policies(policies)
    profiles = []
    policies.collect! do |p|
      if p.kind_of?(MiqPolicySet)
        profiles.push(p)
        p = p.members
      end
      p
    end

    profiles
  end
  private_class_method :separate_profiles_from_policies

  def add_action_for_event(event, action, opt_hash = nil)
    # we now expect an options hash provided by the UI, merge the qualifier with the options_hash
    # overwriting with the values from the options hash
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

    pevent = miq_policy_contents.build(opt_hash)
    pevent.miq_event_definition  = event
    pevent.miq_action = action
    pevent.save

    self.save!
  end
  private :add_action_for_event
end
