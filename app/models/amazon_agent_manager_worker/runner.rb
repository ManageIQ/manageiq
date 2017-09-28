require 'amazon_ssa_support'

class AmazonAgentManagerWorker::Runner < MiqWorker::Runner
  def do_work
    self.class.all_amazon_agent_manager_in_zone.each do |m|
      agents = m.alive_agent_ids

      _log.info("Alive agents in EMS(guid=#{m.ems.guid}): #{agents}.")
      m.setup_agent if m.get_request_message?
    end
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
    all_ems_in_zone.select(&:enabled)
  end

  def self.all_amazon_ems_in_zone
    all_valid_ems_in_zone.select { |e| e.kind_of?(ManageIQ::Providers::Amazon::CloudManager) }
  end

  def self.all_amazon_agent_manager_in_zone
    all_amazon_ems_in_zone.collect { |e| AmazonAgentManager.new(e) }
  end
end
