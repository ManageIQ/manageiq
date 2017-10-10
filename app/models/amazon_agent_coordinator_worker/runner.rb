require 'amazon_ssa_support'

class AmazonAgentCoordinatorWorker::Runner < MiqWorker::Runner
  def do_before_work_loop
    @coordinators = self.class.all_amazon_agent_coordinators_in_zone
  end

  def do_work
    @coordinators.each do |m|
      alive_agents = m.alive_agent_ids

      _log.info("Alive agents in EMS(guid=#{m.ems.guid}): #{alive_agents}.")

      # Only setup agents when:
      # 1. there is no running agents;
      # 2. get new requests;
      # 3. coordinator is not in deploying agent state; 
      m.setup_agent if alive_agents.empty? && !m.request_queue_empty? && !m.deploying?

      # Turn flag off if deploying is done.
      m.deploying = false unless alive_agents.empty?
    end

    # Amazon providers may be added/removed. Keep monitor and update if needed.
    latest_ems_guids = self.class.amazon_ems_guids
    coordinator_guids = @coordinators.collect { |m| m.ems.guid }
    self.class.refresh_coordinators(@coordinators, coordinator_guids, latest_ems_guids)
  end

  def self.agent_coordinator_by_guid(guid)
    all_amazon_agent_coordinators_in_zone.find { |e| e.ems.guid == guid }
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
    all_ems_in_zone.select {|e| e.enabled && e.authentication_status_ok?}
    #all_ems_in_zone.select(&:enabled)
  end

  def self.all_amazon_ems_in_zone
    all_valid_ems_in_zone.select { |e| e.kind_of?(ManageIQ::Providers::Amazon::CloudManager) }
  end

  def self.all_amazon_agent_coordinators_in_zone
    all_amazon_ems_in_zone.collect { |e| AmazonAgentCoordinator.new(e) }
  end

  def self.refresh_coordinators(coordinators, old_guids, new_guids)
    to_delete = old_guids - new_guids
    coordinators.delete_if { |m| to_delete.include?(m.ems.guid) } if to_delete.any?

    to_create = new_guids - old_guids
    to_create.each { |guid | coordinators << AmazonAgentManager.new(ems_by_guid(guid)) }
  end
end
