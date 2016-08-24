class ContainerTemplate < ApplicationRecord
  include CustomAttributeMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project
  has_many :container_template_parameters, :dependent => :destroy
  has_many :labels, -> { where(:section => "labels") },
           :class_name => CustomAttribute,
           :as         => :resource,
           :dependent  => :destroy

  serialize :objects, Array

  acts_as_miq_taggable

  MIQ_ENTITY_MAPPING = {
    "Route"                 => ContainerRoute,
    "Build"                 => ContainerBuildPod,
    "BuildConfig"           => ContainerBuild,
    "Template"              => ContainerTemplate,
    "ResourceQuota"         => ContainerQuota,
    "LimitRange"            => ContainerLimit,
    "ReplicationController" => ContainerReplicator,
    "PersistentVolumeClaim" => PersistentVolumeClaim,
    "Pod"                   => ContainerGroup,
    "Service"               => ContainerService,
  }.freeze

  def instantiate(params, project = nil)
    project ||= container_project.name
    processed_template = process_template(ext_management_system.connect,
                                          :metadata   => {
                                            :name      => name,
                                            :namespace => project
                                          },
                                          :objects    => objects,
                                          :parameters => params)
    create_objects(processed_template['objects'], project)
    @created_objects.each { |obj| obj[:kind] = MIQ_ENTITY_MAPPING[obj[:kind]] }
  end

  def process_template(client, template)
    client.process_template(template)
  rescue KubeException => e
    raise MiqException::MiqProvisionError, "Unexpected Exception while processing template: #{e}"
  end

  def create_objects(objects, project)
    @created_objects = []
    objects.each { |obj| @created_objects << create_object(obj, project).to_h }
  end

  def create_object(obj, project)
    obj = obj.symbolize_keys
    obj[:metadata][:namespace] = project
    method_name = "create_#{obj[:kind].underscore}"
    begin
      ext_management_system.connect_client(obj[:apiVersion], method_name).send(method_name, obj)
    rescue KubeException => e
      rollback_objects(@created_objects)
      raise MiqException::MiqProvisionError, "Unexpected Exception while creating object: #{e}"
    end
  end

  def rollback_objects(objects)
    objects.each { |obj| rollback_object(obj) }
  end

  def rollback_object(obj)
    method_name = "delete_#{obj[:kind].underscore}"
    begin
      ext_management_system.connect_client(obj[:apiVersion], method_name).send(method_name,
                                                                               obj[:metadata][:name],
                                                                               obj[:metadata][:namespace])
    rescue KubeException => e
      _log.error("Unexpected Exception while deleting object: #{e}")
    end
  end
end
