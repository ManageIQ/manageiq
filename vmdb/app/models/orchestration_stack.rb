require 'ancestry'
class OrchestrationStack < ActiveRecord::Base
  include NewWithTypeStiMixin

  has_ancestry

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "EmsCloud"
  belongs_to :template, :class_name => "OrchestrationTemplate"

  has_many   :vms, :class_name => "VmCloud"
  has_many   :security_groups
  has_many   :cloud_networks
  has_many   :parameters, :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackParameter"
  has_many   :outputs,    :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackOutput"
  has_many   :resources,  :dependent => :destroy, :foreign_key => :stack_id, :class_name => "OrchestrationStackResource"

  # @param options [Hash] what to update for the stack. Option keys and values are:
  #   :template (String, URI, S3::S3Object, Object) - A new stack template.
  #     This may be provided in a number of formats including:
  #       a String, containing the template in CFN or HOT format.
  #       a URL String pointing to the document in S3.
  #       a URI object pointing to the document in S3.
  #       an S3::S3Object which contains the template.
  #       an Object which responds to #to_json and returns the template.
  #   :parameters (Hash) - A hash that specifies the input parameters of the new stack.
  def raw_update_stack(_options)
    raise "Abstract Method"
  end

  def raw_delete_stack
    raise "Abstract Method"
  end
end
