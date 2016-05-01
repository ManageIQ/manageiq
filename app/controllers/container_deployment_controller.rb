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
    deployment.create_deployment
  end
end
