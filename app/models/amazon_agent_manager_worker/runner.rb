require 'amazon_ssa_support'

class AmazonAgentManagerWorker::Runner < MiqQueueWorkerBase::Runner
  def do_work
    self.class.all_amazon_agent_manager_in_zone.each do |m|
      agents = m.alive_agent_ids

      _log.info("EMS [guid=#{m.ems.guid}] has #{agents.count} available Amazon SSA agents.")
      #next
    end
  end

  def self.find_or_create_agent(guid)
    manager = agent_manager_by_guid(guid)
    raise "No EMS [#{guid}] is found." if manager.nil?
    if manager.alive_agent_ids.count > 0
      _log.info("Using agent #{manager.alive_agent_ids[0]} to fleece")
      manager.alive_agent_ids[0]
    # TODO: use the existing agents
    else
      _log.info("Creating an Amazon SSA agent ...")
      manager.deploy_agent
    end
  end

  def self.agent_manager_by_guid(guid)
    all_amazon_agent_manager_in_zone.find { |e| e.ems.guid == guid }
  end

  def self.ems_by_guid(guid)
    all_valid_ems_in_zone.detect { |e| e.guid == guid }
  end

  def self.amazon_ems_guids
    all_amazon_ems_in_zone.collect { |e| e.guid }
  end

  def self.all_ems_in_zone
    ExtManagementSystem.where(:zone_id => MiqServer.my_server.zone.id).to_a
  end

  def self.all_valid_ems_in_zone
    #all_ems_in_zone.select {|e| e.enabled && e.authentication_status_ok?}
    all_ems_in_zone.select { |e| e.enabled }
  end

  def self.all_amazon_ems_in_zone
    all_valid_ems_in_zone.select { |e| e.kind_of?(ManageIQ::Providers::Amazon::CloudManager) }
  end

  def self.all_amazon_agent_manager_in_zone
    all_amazon_ems_in_zone.collect { |e| AmazonAgentManager.new(e) }
  end
end
