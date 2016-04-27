module MiqAeMethodService
  module MiqAeServiceRbac
    extend ActiveSupport::Concern

    module ClassMethods
      def find_ar_object_by_id(id)
        rbac = Thread.current.thread_variable_get(:miq_rbac)
        rbac ? Rbac.search(:class => model, :targets => [id], :results_format => :objects).first.first : model.send(:find, *id)
      end

      def all
        rbac = Thread.current.thread_variable_get(:miq_rbac)
        objs = rbac ? Rbac.search(:class => model, :results_format => :objects).first : model.send(:all)
        wrap_results(objs)
      end

      def count
        rbac = Thread.current.thread_variable_get(:miq_rbac)
        rbac ? Rbac.search(:class => model).first.count :  model.send(:count)
      end

      def first
        all.first
      end

      def filter_objects(objs)
        return objs if objs.nil?
        array = Array.wrap(objs)
        return [] if array.empty?

        rbac = Thread.current.thread_variable_get(:miq_rbac)
        ret = rbac ? Rbac.filtered(array) : array
        (objs.kind_of?(Array) || objs.kind_of?(ActiveRecord::Relation)) ? ret : ret.first
      end
    end
  end
end
