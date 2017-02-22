module Api
  class SharedVmsController < BaseController
    def index
      resources = Rbac.resources_shared_with(User.current_user)
      # TODO: if this is a relation, we need to filter in SQL
      shared_vms = resources.select { |resource| resource.kind_of?(Vm) }
      render_collection(:shared_vms, shared_vms)
    end

    def show
      resources = Rbac.resources_shared_with(User.current_user)
      shared_vm = resources.select { |resource| resource.kind_of?(Vm) }
                           .detect { |resource| resource.id == @req.c_id }
      raise NotFoundError unless shared_vm
      render_resource(:shared_vms, shared_vm)
    end
  end
end
