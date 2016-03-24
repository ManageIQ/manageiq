class ContainerDeploymentController < ApplicationController
  extend ActiveSupport::Concern

  # before_action :check_privileges
  after_action :cleanup_action

  def new
    @layout = 'openshift_deployment'
    if params[:id].nil?
      @breadcrumbs.clear
    end
  end

  def data
    render :json => {:data => collect_data}
  end

  def create
    create_new_deployment(params)
    render :json => {:data => "good"}
  end

  def collect_data
    DeploymentService.new.all_data
  end

  private

  def create_or_get_tag(tag)
    ent = Tag.find_by_name(tag)
    unless ent
      ent = Tag.new(:name => tag)
      ent.save
    end
    ent
  end

  def create_automation_request(parameters)
    options = {}
    options[:namespace]     = 'Deployment/System/StateMachine'
    options[:class_name]    = 'Deployment'
    options[:instance_name] = 'Deployment'
    attrs = parameters
    attrs[:userid]     = current_user.userid
    options[:user_id]  = current_user.id
    options[:attrs]    = attrs
    AutomationRequest.create_request(options, current_user, true)
  end

  def create_new_deployment(params)
    deployment = ContainerDeployment.new
    deployment.create_deployment_auth(params)
    deployment.deployment_version = params["version"]
    deployment.deployment_type = params["deployment_type"]
    deployment.deployment_method = params["deployment_method"]
    deployment.ssh_private = params["ssh_private_key"] if params["ssh_private_key"]
    deployment.ssh_user = params["ssh_user"] ? params["ssh_user"] : "root"
    tags = create_needed_tags(params)
    labels = params[:labels]
    if deployment.deployment_method.include? "managed_existing"
      managed_existing(deployment, params, tags, labels)
    elsif deployment.deployment_method.include? "managed_provision"
      managed_provision(deployment, params, tags, labels)
    else
      unmanaged(deployment, params, tags, labels)
    end
    deployment.save!
    create_automation_request(deployment.generate_automation_params(params))
  end

  def managed_existing(deployment, params, tags, labels)
    deployment.deployed_on_ext_management_system = ExtManagementSystem.find params["deployed_on_ext_management_system_id"]
    deployment.create_deployment_nodes([params["nodes_id_or_ip"], params["masters_id_or_ip"], [params["deployment_master_id_or_ip"]]] + add_additional_roles(params), labels, tags, true)
  end

  def managed_provision(deployment, params, tags, labels)
    ContainerDeployment.add_basic_root_template
    deployment.deployed_on_ext_management_system = ExtManagementSystem.find params["deployed_on_ext_management_system_id"]
    deployment.generate_ssh_keys
    deployment.rhsm_user = params["rhsm_user"] if params["rhsm_user"]
    deployment.rhsm_pass = params["rhsm_pass"] if params["rhsm_pass"]
    deployment.rhsm_sku = params["rhsm_sku"] if params["rhsm_sku"]
    deployment.rhsm_pool_id = params["rhsm_pool_id"] if params["rhsm_pool_id"]
    deployment.create_deployment_nodes([params["nodes_id_or_ip"], params["masters_id_or_ip"], [params["deployment_master_id_or_ip"]]] + add_additional_roles(params), labels, tags, nil, true)
  end

  def unmanaged(deployment, params, tags, labels)
    deployment.create_deployment_nodes([params["nodes_id_or_ip"], params["masters_id_or_ip"], [params["deployment_master_id_or_ip"]]] + add_additional_roles(params), labels, tags, nil, true)
  end

  def create_needed_tags(params)
    node_tag = create_or_get_tag("node").name
    master_tag = create_or_get_tag("master").name
    deployment_master_tag = create_or_get_tag("deployment_master").name
    tags = [node_tag, master_tag, deployment_master_tag]
    nfs_tag = create_or_get_tag("nfs").name if params["nfs_id_or_ip"] || params["num_of_nfs"]
    tags += [nfs_tag] if nfs_tag
    tags
  end

  def add_additional_roles(params)
    additional_roles_vms = []
    additional_roles_vms = [params["nfs_id_or_ip"]] if params["nfs_id_or_ip"]
    additional_roles_vms = [(1..params["num_of_nfs"])] if params["num_of_nfs"]
    additional_roles_vms
  end
end
