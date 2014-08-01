require 'digest/md5'
class OrchestrationTemplate < ActiveRecord::Base
  has_many :stacks, :foreign_key => :template_id, :class_name => "OrchestrationStack"

  # Find only by template content. Here we only compare md5 considering the table is expected
  # to be small and the chance of md5 collision is minimal.
  #
  def self.find_or_create_by_contents(hashes)
    md5s = []
    hashes.each do |hash|
      hash[:ems_ref] ||= Digest::MD5.hexdigest(hash[:template])
      md5s << hash[:ems_ref]
    end

    existing_templates = find_all_by_ems_ref(md5s).each_with_object({}) do |template, template_hash|
      template_hash[template.ems_ref] = template
    end

    hashes.collect do |hash|
      md5 = hash[:ems_ref]
      existing_templates.key?(md5) ? existing_templates[md5] : create(hash)
    end
  end

  # Check whether a template has been referenced by any stack. A template that is in use should be
  # considered read only
  def in_use?
    OrchestrationStack.exists?(:template_id => id)
  end

  # Find all read-only templates
  def self.find_all_in_use
    select("DISTINCT orchestration_templates.*").joins(:stacks)
  end

  # Fina all editable templates
  def self.find_all_not_in_use
    includes(:stacks).where("orchestration_stacks.template_id IS NULL")
  end

  # deploy the template to a cloud as a stack
  # @param options [Hash] can contain the following keys and values:
  #   :capabilities (Array<String>) - The list of capabilities that you want to allow in the stack.
  #        If your stack contains IAM resources, you must specify the CAPABILITY_IAM value for this parameter;
  #        otherwise, this action returns an InsufficientCapabilities error. IAM resources are the following:
  #     AWS::IAM::AccessKey
  #     AWS::IAM::Group
  #     AWS::IAM::Policy
  #     AWS::IAM::User
  #     AWS::IAM::UserToGroupAddition
  #   :disable_rollback (Boolean) - default: false - Set to true to disable rollback on stack creation failures.
  #   :notify (Object)   - One or more SNS topics ARN string or SNS::Topic objects. This param may be passed as a
  #                        single value or as an array.
  #                        CloudFormation will publish stack related events to these topics.
  #   :parameters (Hash) - A hash that specifies the input parameters of the new stack.
  #   :timeout (Integer) - The number of minutes that may pass before the stack creation fails.
  #                        If :disable_rollback is false, the stack will be rolled back.
  def deploy(ems, stack_name, options = {})
    if ems.is_a? EmsAmazon
      ems.with_provider_connection(:service => "CloudFormation") do |connection|
        connection.create(stack_name, template, options)
      end
    end
  end
end
