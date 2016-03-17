class ConfigurationScript < ActiveRecord::Base
  belongs_to  :manager,
              :class_name  => 'ManageIQ::Providers::ConfigurationManager',
              :foreign_key => :configuration_manager_id
  include ProviderObjectMixin

  def run(vars = {})
    extra_vars = {'extra_vars' => variables}
    options = vars.reverse_merge(extra_vars)
    with_provider_object do |jt|
      jt.launch(options)
    end
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.job_templates.find(manager_ref)
  end
end
