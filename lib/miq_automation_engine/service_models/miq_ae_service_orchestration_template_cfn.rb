module MiqAeMethodService
  class MiqAeServiceOrchestrationTemplateCfn < MiqAeServiceOrchestrationTemplate
    CREATE_ATTRIBUTES = [:name, :description, :content, :draft, :orderable].freeze

    def self.create(options = {})
      attributes = options.symbolize_keys.slice(*CREATE_ATTRIBUTES)

      ar_method { MiqAeServiceOrchestrationTemplateCfn.wrap_results(OrchestrationTemplateCfn.create!(attributes)) }
    end
  end
end
