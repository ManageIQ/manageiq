require 'actionwebservice'

class MiqservicesApi < ActionWebService::API::Base
  api_method :start_update,
       :expects => [:string],
       :returns => [:bool]

  api_method :end_update,
       :expects => [:string],
       :returns => [:bool]

  api_method :register_vm,
       :expects => [:string, :string, :string],
       :returns => [:int]

  api_method :save_vmmetadata,
       :expects => [:string, :string, :string, :string],
       :returns => [:bool]

  api_method :test_statemachine,
       :expects => [:string, :string, :string],
       :returns => [:bool]

  api_method :save_hostmetadata,
       :expects => [:string, :string, :string],
       :returns => [:bool]

  api_method :vm_status_update,
       :expects => [:string, :string],
       :returns => [:bool]

  api_method :agent_unregister,
       :expects => [:string, :string],
       :returns => [:bool]

  api_method :policy_check_vm,
       :expects => [:string, :string],
       :returns => [:string]

  api_method :start_service,
       :expects => [:string, :string, :string],
       :returns => [:bool]

  api_method :host_heartbeat,
       :expects => [:string, :string, :string],
       :returns => [:string]

  api_method :save_xmldata,
       :expects => [:string, :string],
       :returns => [:bool]

  api_method :agent_config,
       :expects => [:string, :string],
       :returns => [:string]

  api_method :agent_register,
       :expects => [:string],
       :returns => [:string]

  api_method :agent_job_state,
      :expects => [:string, :string, :string],
      :returns => [:bool]

  api_method :task_update,
      :expects => [:string, :string, :string, :string],
      :returns => [:bool]

  api_method :queue_async_response,
      :expects => [:string, :string],
      :returns => [:bool]

#  api_method :test_ws,
#      :returns => [[[:string]]]
end
