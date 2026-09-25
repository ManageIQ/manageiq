module MiqPolicyMixin
  extend ActiveSupport::Concern

  included do
    tag_attribute :policy, "/miq_policy/assignment"
  end

  def add_policy(policy)
    ns = "/miq_policy"
    cat = "assignment/#{policy.class.to_s.underscore}"
    tag = policy.id.to_s

    tag_add(tag, :ns => ns, :cat => cat)
    reload
  end

  def remove_policy(policy)
    ns = "/miq_policy"
    cat = "assignment/#{policy.class.to_s.underscore}"
    tag = policy.id.to_s

    tags = tag_list(:ns => ns, :cat => cat).split
    tags.delete(tag)

    tag_with(tags.join(" "), :ns => ns, :cat => cat)
    reload
  end

  def get_policies
    policy_tags
      .map { |t| t.split("/").first(2) }
      .group_by(&:first)
      .select { |klass, _ids| ["miq_policy", "miq_policy_set"].include?(klass) }
      .flat_map { |klass, ids| klass.camelize.constantize.where(:id => ids.map(&:last)).to_a }
  end

  def resolve_policies(list, event = nil)
    MiqPolicy.resolve(self, list, event)
  end

  def resolve_profiles(list, event = nil)
    result = []
    list.each do |pid|
      prof = MiqPolicySet.find(pid)
      next unless prof

      plist = prof.members.collect(&:name)
      presults = resolve_policies(plist, event)

      next if presults.empty? # skip profiles that had no policies due to the event not matching or no policies in scope

      prof_result = "allow"
      presults.each do |r|
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
    plist.each do |policy|
      result = false if policy["result"] == "deny"
    end
    result_list = plist.collect { |r| r["result"] }.uniq
    result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
    result
  end

  def passes_profiles?(list)
    plist = resolve_profiles(list)
    result = true
    plist.each do |prof|
      result = false if prof["result"] == "deny"
    end
    result_list = plist.collect { |r| r["result"] }.uniq
    result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
    result
  end

  def parent_enterprise
    MiqEnterprise.my_enterprise
  end

  # cb_method: the MiqQueue callback method along with the parameters that is called
  #            when automate process is done and the request is not prevented to proceed by policy
  def prevent_callback_settings(*cb_method)
    {
      :class_name  => self.class.to_s,
      :instance_id => id,
      :method_name => :check_policy_prevent_callback,
      :args        => [*cb_method],
      :server_guid => MiqServer.my_guid
    }
  end

  # Same as prevent_callback_settings, but the callback also finishes the MiqTask (task_id)
  # that the in-flight queue message was tracking.
  def prevent_task_callback_settings(task_id, *cb_method)
    prevent_callback_settings(*cb_method).merge(:method_name => :check_policy_prevent_task_callback, :args => [task_id, *cb_method])
  end

  def check_policy_prevent_callback(*action, _status, _message, result)
    prevented, message = policy_prevention(result)

    if prevented
      _log.info(message)
    else
      kwargs = action.extract_options!
      send(*action, **kwargs)
    end
  end

  def check_policy_prevent_task_callback(task_id, *action, _status, _message, result)
    prevented, message = policy_prevention(result)
    task = MiqTask.find_by(:id => task_id)

    if prevented
      _log.info(message)
      task&.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, message.presence || MiqTask::MESSAGE_TASK_COMPLETED_UNSUCCESSFULLY)
      return
    end

    kwargs = action.extract_options!
    return send(*action, **kwargs) if task.nil?

    # A *_queue action that accepts miq_task_id hands the task to the message it queues,
    # which finishes the task when that message is processed.
    handoff = method(action.first).parameters.include?([:key, :miq_task_id])
    kwargs[:miq_task_id] = task_id if handoff

    begin
      result = send(*action, **kwargs)
    rescue => err
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, err.message)
      raise
    end

    if handoff && result.nil?
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, "queue message not created")
    elsif !(handoff && result.kind_of?(MiqQueue) && result.miq_task_id == task_id)
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, MiqTask::MESSAGE_TASK_COMPLETED_SUCCESSFULLY)
    end
  end

  # Options that let a raw_* queue message finish the task (task_id) handed over by check_policy_prevent_task_callback.
  def policy_prevent_task_queue_options(task_id)
    return {} if task_id.nil?

    {
      :miq_task_id  => task_id,
      :miq_callback => {
        :class_name  => MiqTask.name,
        :instance_id => task_id,
        :method_name => :queue_callback,
        :args        => ["Finished"]
      }
    }
  end

  # Raises the policy event via the block, which is passed the miq_callback to use for the automate job.
  #
  # When running inside a queue message that tracks a MiqTask, the task must not be finished by that message
  # when the action only raised a policy event: the automate job's callback finishes it instead.
  def policy_prevent_with_task_handoff(*cb_method)
    task_id = policy_prevent_current_task_id
    return yield(prevent_callback_settings(*cb_method)) if task_id.nil?

    queued = policy_event_queueable?
    event = yield(prevent_task_callback_settings(task_id, *cb_method))
    return event unless event

    unless queued
      MiqTask.find_by(:id => task_id)&.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, "Policy event not queued (zone in maintenance); action not run")
    end

    msg = policy_prevent_current_msg
    msg.miq_callback = nil
    msg.clear_attribute_changes([:miq_callback]) # so that MiqQueue#unget does not persist the cleared callback
    event
  end

  private

  def policy_prevention(result)
    return [false, nil] unless result.kind_of?(MiqAeEngine::MiqAeWorkspaceRuntime)

    event = result.get_obj_from_path("/")['event_stream']
    data  = event.attributes["full_data"]
    [data ? data.fetch_path(:policy, :prevented) : false, event.attributes["message"]]
  end

  def policy_prevent_current_msg
    $_miq_worker_current_msg
  end

  # mirrors MiqAeEngine.deliver_queue and MiqQueue.put: no automate message is created in a maintenance zone
  def policy_event_queueable?
    zone = MiqServer.my_server.has_active_role?('automate') ? MiqServer.my_zone : nil
    !Zone.maintenance?(zone)
  end

  # The task tracked by the queue message being processed, when that message is for this record
  # and finishes the task through a callback (MiqTask#queue_callback or VmOrTemplate#powerops_callback).
  def policy_prevent_current_task_id
    msg = policy_prevent_current_msg
    return if msg.nil? || msg.miq_task_id.blank? || msg.instance_id != id

    klass = msg.class_name.to_s.safe_constantize
    return unless klass && kind_of?(klass)

    cb = msg.miq_callback
    return if cb.blank?

    case cb[:method_name].to_s
    when "queue_callback"
      msg.miq_task_id if cb[:class_name] == MiqTask.name && cb[:instance_id] == msg.miq_task_id
    when "powerops_callback"
      msg.miq_task_id if cb[:instance_id] == id && cb[:args]&.first == msg.miq_task_id
    end
  end

  module ClassMethods
    def rsop(event, targets)
      eventobj = event.kind_of?(String) ? MiqEventDefinition.find_by(:name => event) : MiqEventDefinition.extract_objects(event)
      raise _("No event found for [%{event}]") % {:event => event} if eventobj.nil?

      targets = extract_objects(targets)

      result = []
      targets.each do |t|
        profiles = (t.get_policies + MiqPolicy.associations_to_get_policies.collect do |assoc|
          next unless t.respond_to?(assoc)

          t.send(assoc).get_policies unless t.send(assoc).nil?
        end).compact.flatten.uniq
        presults = t.resolve_profiles(profiles.collect(&:id), eventobj)
        target_result = presults.inject("allow") do |s, r|
          break "deny" if r["result"] == "deny"

          s
        end

        result_list = presults.collect { |r| r["result"] }.uniq
        target_result = result_list.first if result_list.length == 1 && result_list.first == "N/A"
        result.push("id" => t.id, "name" => t.name, "result" => target_result, "profiles" => presults)
      end
      result
    end

    def rsop_async(event, targets, userid = nil)
      eventobj = event.kind_of?(String) ? MiqEventDefinition.find_by(:name => event) : MiqEventDefinition.extract_objects(event)
      raise _("No event found for [%{event}]") % {:event => event} if eventobj.nil?

      targets = targets.collect(&:id) if targets.first.kind_of?(self)

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
      MiqTask.generic_action_with_callback(opts, qopts)
    end
  end # module ClassMethods
end # module MiqPolicyMixin
