require 'amazon_ssa_support'

class AmazonAgentManagerWorker::Runner < MiqWorker::Runner
  def do_work
    self.class.all_amazon_agent_manager_in_zone.each do |m|
      agents = m.alive_agent_ids

      _log.info("Alive agents in EMS(guid=#{m.ems.guid}): #{agents}.")
      m.setup_agent if m.get_request_message?
    end
  end

###  def self.find_or_create_agent(guid, max_wait_for_minute = 10)
###    manager = agent_manager_by_guid(guid)
###    raise "No EMS [#{guid}] is found." if manager.nil?
###
###    # Use the 1st available agent if any
###    if manager.alive_agent_ids.count > 0
###      _log.info("Using agent #{manager.alive_agent_ids[0]} to fleece")
###      return manager.alive_agent_ids[0]
###    end
###
###    # Power on the agent if it's in hibernate state
###    agent_id = nil
###    if manager.agent_ids.count > 0
###      manager.agent_ids.each do |id|
###        _log.info("Power on the agent #{id}")
###        begin
###          agent_id = manager.activate_agent(id)
###          break
###        rescue => e
###          log.error(e.message)
###        end
###      end
###
###      # All stopped agents couldn't be powered on, create a new one.
###      if agent_id.nil?
###        _log.warn("Could not activate agents: #{manager.agent_ids}, deploy a new one.")
###        agent_id = manager.deploy_agent
###      end
###    else
###      _log.info("Creating an Amazon SSA agent ...")
###      agent_id = manager.deploy_agent
###    end
###
###    raise "No agent can be deployed in #{guid}" if agent_id.nil?
###
###    max_wait_for_minute.times do
###_log.info("HUIS==> agent_id=#{agent_id}")
###      return agent_id if manager.agent_alive?(agent_id) 
###
###      sleep(1.minutes)
###      _log.info("Waiting for Amazon agent starting ...")
###    end
###
###    raise "Failed to prepare an Amazon SSA agent for #{guid}!"
###  end

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
