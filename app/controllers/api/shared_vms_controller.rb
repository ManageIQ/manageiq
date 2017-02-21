module Api
  class SharedVmsController < BaseController
    def index
      resources = Rbac.resources_shared_with(User.current_user)
      # TODO: if this is a relation, we need to filter in SQL
      shared_vms = resources.select { |resource| resource.kind_of?(Vm) }
      render_collection(:shared_vms, shared_vms)
    end
  end
end
