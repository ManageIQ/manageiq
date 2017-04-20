module ManageIQ::Providers
  module Elasticsearch
    class DatawarehouseManager::Parser_1_7_6 < ManageIQ::Providers::Elasticsearch::DatawarehouseManager::RefreshParser
      def parse_node(id, stats)
        stats = RecursiveOpenStruct.new(stats) # for nil fields
        ip, port = stats.ip.first.split(':')
        {
          :ems_ref => id,
          :name    => stats.name,

          :host    => stats.host,
          :ip      => ip,
          :port    => port,

          :master  => stats.attributes.master,
          :load    => stats.os.load_average[0],
          :mem     => stats.os.mem.used_percent,
          :heap    => stats.jvm.mem.heap_used_percent,
          :disk    => self.class.parse_disk_usage(stats.fs.total),
          :cpu     => stats.os.cpu_percent
        }
      end
    end
  end
end
