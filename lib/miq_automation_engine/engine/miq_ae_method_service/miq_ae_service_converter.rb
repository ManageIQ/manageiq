module MiqAeMethodService
  class MiqAeServiceConverter
    def self.svc2obj(svc)
      svc.instance_variable_get("@object")
    end
  end
end
