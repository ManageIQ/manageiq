require 'amazon_ssa_support'

class AmazonAgentManagerWorker::Runner < MiqWorker::Runner
  def do_before_work_loop
    @managers = self.class.all_amazon_agent_manager_in_zone
  end

  def do_work
    @managers.each do |m|
      alive_agents = m.alive_agent_ids

      _log.info("Alive agents in EMS(guid=#{m.ems.guid}): #{alive_agents}.")

      # Only setup agents when:
      # 1. there is no running agents;
      # 2. get new requests;
      # 3. manager is not in deploying agent state;
      m.setup_agent if alive_agents.empty? && !m.request_queue_empty? && !m.deploying?

      # Turn flag off if deploying is done.
      m.deploying = false unless alive_agents.empty?
    end

    # Amazon providers may be added/removed. Keep monitor and update if needed.
    latest_ems_guids = self.class.amazon_ems_guids
    manager_guids = @managers.collect { |m| m.ems.guid }
    self.class.refresh_managers(@managers, manager_guids, latest_ems_guids) unless manager_guids == latest_ems_guids
  end

  def self.agent_manager_by_guid(guid)
    all_amazon_agent_manager_in_zone.find { |e| e.ems.guid == guid }
  end

  def self.ems_by_guid(guid)
    all_valid_ems_in_zone.detect { |e| e.guid == guid }
  end

  def self.amazon_ems_guids
    all_amazon_ems_in_zone.collect(&:guid)
  end

  def self.all_ems_in_zone
    ExtManagementSystem.where(:zone_id => MiqServer.my_server.zone.id).to_a
  end

  def self.all_valid_ems_in_zone
    # all_ems_in_zone.select {|e| e.enabled && e.authentication_status_ok?}
    all_ems_in_zone.select(&:enabled)
  end

  def self.all_amazon_ems_in_zone
    all_valid_ems_in_zone.select { |e| e.kind_of?(ManageIQ::Providers::Amazon::CloudManager) }
  end

  def self.all_amazon_agent_manager_in_zone
    all_amazon_ems_in_zone.collect { |e| AmazonAgentManager.new(e) }
  end

  def self.refresh_managers(mgrs, old_guids, new_guids)
    _log.info("Updating Amazon providers in appliance")

    extra = old_guids.dup

    new_guids.each do |m|
      if i = extra.index(m)
        extra.delete_at(i)
      end
    end

    unless extra.empty?
      extra.each do |guid|
        mgrs.delete_if { |m| m.ems.guid == guid }
        _log.info("EMS: [#{guid}] is removed from appliance")
      end
    end

    missing = new_guids.dup
    old_guids.each do |m|
      if i = missing.index(m)
        missing.delete_at(i)
      end
    end

    unless missing.empty?
      missing.each do |guid|
        mgs << AmazonAgentManager.new(ems_by_guid(guid))
        _log.info("EMS: [#{guid}] is added from appliance")
      end
    end
  end
end
