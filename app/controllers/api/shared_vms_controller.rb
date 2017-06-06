module Api
  class SharedVmsController < BaseController
    def index
      resources = shared_vms

      # # Roughly what we do elsewhere:

      sort_options = sort_params(Vm)
      resources = resources.reorder(sort_options) if sort_options

      limit, offset = expand_paginate_params if paginate_params?
      resources = resources.limit(limit) if limit
      resources = resources.offset(offset) if offset

      miq_expression = filter_param(Vm)

      if miq_expression
        sql, includes, meta = miq_expression.to_sql
        if meta[:supported_by_sql]
          resources = resources.includes(includes) if includes
          resources = resources.where(sql)
        end
        ruby = miq_expression.to_ruby
        resources = resources.select { |resource| Condition.subst_matches?(ruby, resource) }
      end

      render_collection(:shared_vms, resources)
    end

    def show
      render_resource(:shared_vms, shared_vms.find(@req.c_id))
    end

    private

    def shared_vms
      Vm.shared_with(User.current_user)
    end
  end
end
