module ApplicationHelper
  module Chargeback
    def rate_detail_group(rd_group)
      rd_groups = {
        "cpu"     => _("CPU"),
        "disk_io" => _("Disk I/O"),
        "fixed"   => _("Fixed"),
        "memory"  => _("Memory"),
        "net_io"  => _("Network I/O"),
        "storage" => _("Storage")
      }
      if rd_groups.key?(rd_group)
        rd_groups[rd_group]
      else
        rd_group.titleize
      end
    end
  end
end
