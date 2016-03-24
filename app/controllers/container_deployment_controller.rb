class ContainerDeploymentController < ApplicationController
  extend ActiveSupport::Concern

  # before_action :check_privileges
  after_action :cleanup_action
  skip_before_action :verify_authenticity_token # need to remove later on

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
    options[:namespace]     = 'ManageIQ/Deployment/ContainerProvider/System/StateMachine'
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
    deployment.version = params["version"]
    deployment.kind = params["deployment_type"]
    deployment.method_type = params["deployment_method"]
    tags = create_needed_tags(params)
    labels = params[:labels]
    if deployment.method_type.include? "managed_existing"
      managed_existing(deployment, params, tags, labels)
    elsif deployment.method_type.include? "managed_provision"
      managed_provision(deployment, params, tags, labels)
    else
      unmanaged(deployment, params, tags, labels)
    end
    deployment.create_deployment_authentication(params[:authentication])
    deployment.create_deployment_authentication(params[:rhsm_authentication]) if params[:rhsm_authentication]
    deployment.create_deployment_authentication(params[:ssh_authentication])
    deployment.save!
    create_automation_request(deployment.generate_automation_params(params))
  end

  def managed_existing(deployment, params, tags, labels)
    deployment.deployed_on_ems = ExtManagementSystem.find params["deployed_on_ext_management_system_id"]
    deployment.create_deployment_nodes([params["nodes_addresses"], params["masters_addresses"], [params["deployment_master_address"]]] + add_additional_roles(params), labels, tags, true)
  end

  def managed_provision(deployment, params, tags, labels)
    ContainerDeployment.add_basic_root_template
    deployment.deployed_on_ems = ExtManagementSystem.find params["deployed_on_ext_management_system_id"]
    public_key, private_key = deployment.generate_ssh_keys
    params[:ssh_authentication][:auth_key] = private_key
    params[:ssh_authentication][:public_key] = public_key
    params[:ssh_authentication][:userid] = "root"
    deployment.create_deployment_nodes([params["nodes_addresses"], params["masters_addresses"], [params["deployment_master_address"]]] + add_additional_roles(params), labels, tags, nil, true)
  end

  def unmanaged(deployment, params, tags, labels)
    deployment.create_deployment_nodes([params["nodes_addresses"], params["masters_addresses"], [params["deployment_master_address"]]] + add_additional_roles(params), labels, tags, nil, true)
  end

  def create_needed_tags(params)
    node_tag = create_or_get_tag("node").name
    master_tag = create_or_get_tag("master").name
    deployment_master_tag = create_or_get_tag("deployment_master").name
    tags = [node_tag, master_tag, deployment_master_tag]
    nfs_tag = create_or_get_tag("nfs").name if params["nfs_id_or_ip"]
    tags += [nfs_tag] if nfs_tag
    tags
  end

  def add_additional_roles(params)
    additional_roles_vms = []
    additional_roles_vms = [params["nfs_id_or_ip"]] if params["nfs_id_or_ip"]
    additional_roles_vms
  end
end
