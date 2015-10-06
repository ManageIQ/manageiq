module MiqPolicyMixin
  extend ActiveSupport::Concern

  def add_policy(policy)
    ns = "/miq_policy"
    cat = "assignment"
    cat += "/" + policy.class.to_s.underscore
    tag = policy.id.to_s

    tag_add(tag, :ns => ns, :cat => cat)
    reload
  end

  def remove_policy(policy)
    ns = "/miq_policy"
    cat = "assignment"
    cat += "/" + policy.class.to_s.underscore
    tag = policy.id.to_s

    tags = tag_list(:ns => ns, :cat => cat).split
    tags.delete(tag)

    tag_with(tags.join(" "), :ns => ns, :cat => cat)
    reload
  end

  def get_policies(mode = nil)
    ns = "/miq_policy"
    cat = "assignment"
    tag_list(:ns => ns, :cat => cat).split.collect do|t|
      klass, id = t.split("/")
      next unless ["miq_policy", "miq_policy_set"].include?(klass)
      policy = klass.camelize.constantize.find_by_id(id.to_i)
      mode.nil? || policy.mode == mode ? policy : nil
    end.compact
  end

  def has_policies?
    get_policies.length > 0
  end

  def resolve_policies(list, event = nil)
    MiqPolicy.resolve(self, list, event)
  end

  def resolve_profiles(list, event = nil)
    result = []
    list.each do|pid|
      prof = MiqPolicySet.find(pid)
      next unless prof

      plist = prof.members.collect(&:name)
      presults = resolve_policies(plist, event)

      next if presults.empty? # skip profiles that had no policies due to the event not matching or no policies in scope

      prof_result = "allow"
      presults.each do|r|
        if r["result"] == "deny"
          prof_result = "deny"
          break
        end
      end

      result_list = presults.collect { |r| r["result"] }.uniq
      prof_result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
      result.push(prof.attributes.merge("result" => prof_result, "policies" => presults))
    end
    result
  end

  def passes_policy?(list = nil)
    list.nil? ? plist = policies : plist = resolve_policies(list)
    result = true
    plist.each do|policy|
      result = false if policy["result"] == "deny"
    end
    result_list = plist.collect { |r| r["result"] }.uniq
    result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
    result
  end

  def passes_profiles?(list)
    plist = resolve_profiles(list)
    result = true
    plist.each do|prof|
      result = false if prof["result"] == "deny"
    end
    result_list = plist.collect { |r| r["result"] }.uniq
    result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
    result
  end

  def parent_enterprise
    MiqEnterprise.my_enterprise
  end

  module ClassMethods
    def rsop(event, targets)
      eventobj = event.kind_of?(String) ? MiqEventDefinition.find_by_name(event) : MiqEventDefinition.extract_objects(event)
      raise "No event found for [#{event}]" if eventobj.nil?

      targets = extract_objects(targets)

      result = []
      targets.each do |t|
        profiles = (t.get_policies + MiqPolicy.associations_to_get_policies.collect do|assoc|
          next unless t.respond_to?(assoc)
          t.send(assoc).get_policies unless t.send(assoc).nil?
        end).compact.flatten.uniq
        presults = t.resolve_profiles(profiles.collect(&:id), eventobj)
        target_result = presults.inject("allow") { |s, r| break "deny" if r["result"] == "deny"; s }

        result_list = presults.collect { |r| r["result"] }.uniq
        target_result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
        result.push("id" => t.id, "name" => t.name, "result" => target_result, "profiles" => presults)
      end
      result
    end

    def rsop_async(event, targets, userid = nil)
      eventobj = event.kind_of?(String) ? MiqEventDefinition.find_by_name(event) : MiqEventDefinition.extract_objects(event)
      raise "No event found for [#{event}]" if eventobj.nil?

      targets =  targets.first.kind_of?(self) ? targets.collect(&:id) : targets

      opts = {
        :action => "#{name} - Resultant Set of Policy, Event: [#{eventobj.description}]",
        :userid => userid
      }
      qopts = {
        :class_name  => name,
        :method_name => "rsop",
        :args        => [eventobj.name, targets],
        :priority    => MiqQueue::HIGH_PRIORITY
      }
      tid = MiqTask.generic_action_with_callback(opts, qopts)
    end
  end # module ClassMethods
end # module MiqPolicyMixin
