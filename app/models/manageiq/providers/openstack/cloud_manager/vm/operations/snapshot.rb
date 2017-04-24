module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Snapshot
  extend ActiveSupport::Concern

  included do
    supports :snapshot_create do
      unless supports_control?
        unsupported_reason_add(:snapshot_create, unsupported_reason(:control))
      end
    end

    supports :remove_snapshot do
      if supports_snapshots?
        if snapshots.size <= 0
          unsupported_reason_add(:remove_snapshot, _("No snapshots available for this VM"))
        end
        unless supports_control?
          unsupported_reason_add(:remove_snapshot, unsupported_reason(:control))
        end
      else
        unsupported_reason_add(:remove_snapshot, _("Operation not supported"))
      end
    end

    supports :remove_all_snapshots do
      unless supports_remove_snapshot?
        unsupported_reason_add(:remove_all_snapshots, unsupported_reason(:remove_snapshot))
      end
    end

    supports :remove_snapshot_by_description do
      unsupported_reason_add(:remove_snapshot_by_description, _("Operation not supported"))
    end

    supports :revert_to_snapshot do
      unsupported_reason_add(:revert_to_snapshot, _("Operation not supported"))
    end
  end
end
