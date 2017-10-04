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
      m.setup_agent if m.get_request_message? && alive_agents.empty? && !m.deploying?

      # Turn flag off if deploying is done.
      m.deploying = false unless alive_agents.empty?
    end

    # Amazon providers may be added/removed. Keep monitor and update if needed.
    self.clall.refresh_managers unless @managers == self.class.all_amazon_agent_manager_in_zone
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
    #all_ems_in_zone.select {|e| e.enabled && e.authentication_status_ok?}
    all_ems_in_zone.select(&:enabled)
  end

  def self.all_amazon_ems_in_zone
    all_valid_ems_in_zone.select { |e| e.kind_of?(ManageIQ::Providers::Amazon::CloudManager) }
  end

  def self.all_amazon_agent_manager_in_zone
    all_amazon_ems_in_zone.collect { |e| AmazonAgentManager.new(e) }
  end

  def self.refresh_managers
    _log.info("Updating Amazon providers in appliance")

    extra   = @managers.dup
    missing = all_amazon_agent_manager_in_zone

    missing.each { |m| extra.delete_at(i) if i = extra.index(m) }
    @managers = @managers - extra unless extra.empty?

    @managers.each { |m| missing.delete_at(i) if i = missing.index(m) }
    @managers = @managers + missing unless missing.empty?

    @managers.each { |m| _log.info("manager: #{m.ems.guid}") }
  end
end
