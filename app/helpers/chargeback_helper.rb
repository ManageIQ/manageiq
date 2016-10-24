module ChargebackHelper
  def rate_detail_group(rd_group)
    rd_groups = {
      'cpu'     => _('CPU'),
      'disk_io' => _('Disk I/O'),
      'fixed'   => _('Fixed'),
      'memory'  => _('Memory'),
      'net_io'  => _('Network I/O'),
      'storage' => _('Storage')
    }
    rd_groups[rd_group] || rd_group.titleize
  end
end
