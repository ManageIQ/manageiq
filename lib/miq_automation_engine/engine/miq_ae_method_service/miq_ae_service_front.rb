module MiqAeMethodService
  class MiqAeServiceFront
    include DRbUndumped
    attr_accessor :workspace
    def initialize(workspace)
      @workspace = workspace
    end

    def find(id)
      MiqAeService.find(id)
    end
  end
end
