module MiqAeMethodService
  class MiqAeServiceMiqProxy < MiqAeServiceModelBase
    expose :host, :association => true

    def powershell(script, returns = 'string')
      ar_method { @object.powershell_command(script, returns) }
    end

  end
end
