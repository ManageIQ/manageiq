module MiqAeMethodService
  module MiqAeServiceRbac
    extend ActiveSupport::Concern

    module ClassMethods
      def find_ar_object_by_id(id)
        if rbac_enabled?
          Rbac.filtered(model.where(:id => id), :user => workspace.ae_user).first
        else
          model.find(*id)
        end
      end

      def all
        objs = rbac_enabled? ? Rbac.filtered(model, :user => workspace.ae_user) : model.all
        wrap_results(objs)
      end

      def count
        rbac_enabled? ? Rbac.filtered(model, :user => workspace.ae_user).count : model.count
      end

      def first
        objs = rbac_enabled? ? Rbac.filtered(model, :user => workspace.ae_user, :limit => 1) : model
        wrap_results(objs.first)
      end

      def filter_objects(objs)
        if objs.nil?
          objs
        elsif objs.kind_of?(Array) || objs.kind_of?(ActiveRecord::Relation)
          rbac_enabled? ? Rbac.filtered(objs, :user => workspace.ae_user) : objs
        else
          rbac_enabled? ? Rbac.filtered_object(objs, :user => workspace.ae_user) : objs
        end
      end

      def workspace
        MiqAeEngine::MiqAeWorkspaceRuntime.current || MiqAeEngine::DrbRemoteInvoker.workspace
      end

      def workspace_from_drb_thread
        DRb.front.workspace
      rescue DRb::DRbServerNotFound => err
        $miq_ae_logger.warn("Could not fetch DRb front object #{err}")
        nil
      end

      def rbac_enabled?
        workspace && workspace.rbac_enabled?
      end
    end
  end
end
