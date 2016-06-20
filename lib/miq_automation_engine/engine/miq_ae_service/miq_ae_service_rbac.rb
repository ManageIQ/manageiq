module MiqAeMethodService
  module MiqAeServiceRbac
    extend ActiveSupport::Concern

    module ClassMethods
      def find_ar_object_by_id(id)
        MiqAeService.set_current_user if MiqAeService.rbac_enabled?
        MiqAeService.rbac_enabled? ? Rbac.search(:class => model, :targets => [id], :results_format => :objects).first.first : model.send(:find, *id)
      end

      def all
        MiqAeService.set_current_user if MiqAeService.rbac_enabled?
        objs = MiqAeService.rbac_enabled? ? Rbac.filtered(model): model.send(:all)
        wrap_results(objs)
      end

      def count
        MiqAeService.set_current_user if MiqAeService.rbac_enabled?
        MiqAeService.rbac_enabled? ? Rbac.filtered(model).count : model.send(:count)
      end

      def first
        all.first
      end

      def filter_objects(objs)
        return objs if objs.nil?
        array = Array.wrap(objs)
        return [] if array.empty?

        MiqAeService.set_current_user if MiqAeService.rbac_enabled?
        ret = MiqAeService.rbac_enabled? ? Rbac.filtered(array) : array
        (objs.kind_of?(Array) || objs.kind_of?(ActiveRecord::Relation)) ? ret : ret.first
      end
    end
  end
end
