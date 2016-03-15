class ConfigurationScript < ActiveRecord::Base
  belongs_to  :manager,
              :class_name  => 'ManageIQ::Providers::ConfigurationManager',
              :foreign_key => :configuration_manager_id
  include ProviderObjectMixin

  def run(vars = {})
    current_vars = {'extra_vars' => variables}
    extra_vars = vars.reverse_merge(current_vars)
    with_provider_object do |jt|
      jt.launch(extra_vars)
    end
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.job_templates.find(manager_ref)
  end
end
