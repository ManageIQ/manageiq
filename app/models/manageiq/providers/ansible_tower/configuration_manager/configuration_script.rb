class ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript < ConfigurationScript
  def run(vars = {})
    options = vars.merge(merge_extra_vars(vars[:extra_vars]))

    with_provider_object do |jt|
      jt.launch(options)
    end
  end

  def merge_extra_vars(external)
    internal = variables.empty? ? {} : JSON.parse(variables)
    merged_vars = internal.merge(external || {})
    {:extra_vars => merged_vars.to_json}
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.job_templates.find(manager_ref)
  end
end
