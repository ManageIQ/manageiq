class PhysicalServerProfileTemplate < ApplicationRecord
  acts_as_miq_taggable

  include NewWithTypeStiMixin
  include TenantIdentityMixin
  include SupportsFeatureMixin
  include EventMixin
  include ProviderObjectMixin
  include EmsRefreshMixin

  include_concern 'Operations'

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_server_profile_templates,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  delegate :queue_name_for_ems_operations, :to => :ext_management_system, :allow_nil => true

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def self.deploy_server_from_template(template_id, server_id, profile_name)
    # Load the gem
    require 'intersight_client'
    # Setup authorization
    #ManageIQ::Providers::CiscoIntersight::PhysicalInfraManager.first.connect
    bulk = ManageIQ::Providers::CiscoIntersight::PhysicalInfraManager.first.connect(:service=>'BulkApi')

    cloner = IntersightClient::BulkMoCloner.new({:sources=>[{"Moid" => template_id, "ObjectType" => 'server.ProfileTemplate'}],:targets=>[{"Name" => profile_name, "ObjectType": 'server.Profile'}]})

    result = bulk.create_bulk_mo_cloner(cloner)
    new_profile_moid = result.responses[0].body.moid

    server_profile_updated = IntersightClient::ServerProfile.new(
      {
        :assigned_server        => {"Moid" => server_id, "ObjectType" => "compute.Blade"},
        :server_assignment_mode => "Static",
        :target_platform        => nil,
        :uuid_address_type      => nil
      }
    )
    server_api = ManageIQ::Providers::CiscoIntersight::PhysicalInfraManager.first.connect(:service=>'ServerApi')

    begin
      result = server_api.patch_server_profile(new_profile_moid, server_profile_updated, {})
      _log.info("Server profile successfully assigned with server #{server_id} (ems_ref #{result.assigned_server.moid})")
    rescue IntersightClient::ApiError => e
      _log.error("Assign server failed for server profile (ems_ref #{new_profile_moid}) server (ems_ref #{server_id})")
      raise MiqException::Error, "Assign server failed: #{e.response_body}"
    end

    server_profile_updated = {'Action' => "Deploy"}

    begin
      result = server_api.patch_server_profile(new_profile_moid, server_profile_updated, {})
      _log.info("Server profile #{result.config_context.control_action} initiated successfully")
    rescue IntersightClient::ApiError => e
      _log.error("#{action} server failed for server profile (ems_ref #{new_profile_moid})")
      raise MiqException::Error, "#{action} server failed: #{e.response_body}"


    end
  end
end

