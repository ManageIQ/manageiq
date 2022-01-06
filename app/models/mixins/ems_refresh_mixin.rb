module EmsRefreshMixin
  extend ActiveSupport::Concern

  included do
    supports :refresh_ems
  end

  class_methods do
    def queue_refresh(ems_id_or_ids, ems_ref = nil)
      refresh_internal(ems_id_or_ids, ems_ref, :queue => true)
    end
    alias_method :refresh_ems, :queue_refresh

    def refresh(ems_id_or_ids, ems_ref = nil)
      refresh_internal(ems_id_or_ids, ems_ref, :queue => false)
    end

    private

    def refresh_internal(ems_id_or_object_ids, ems_ref, queue:)
      targets =
        if ems_ref.nil?
          Array(ems_id_or_object_ids).map { |id| [base_class, id] }
        else
          ems = ExtManagementSystem.find_by(:id => ems_id_or_object_ids)

          raise _("No Provider defined") if ems.nil?
          raise _("No Provider credentials defined") unless ems.has_credentials?
          raise _("Provider failed last authentication check") unless ems.authentication_status_ok?

          refresh_target(ems, ems_ref)
        end

      refresh_meth = queue ? :queue_refresh : :refresh

      EmsRefresh.public_send(refresh_meth, targets)
    end

    def refresh_target(ems, ems_ref)
      if ems.allow_targeted_refresh?
        InventoryRefresh::Target.new(
          :manager     => ems,
          :association => refresh_association,
          :manager_ref => {:ems_ref => ems_ref}
        )
      else
        ems
      end
    end

    def refresh_association
      base_class.name.tableize.to_sym
    end
  end

  def queue_refresh
    self.class.queue_refresh(ext_management_system&.id, ems_ref)
  end
  alias refresh_ems queue_refresh

  def refresh
    self.class.refresh(ext_management_system&.id, ems_ref)
  end
end
