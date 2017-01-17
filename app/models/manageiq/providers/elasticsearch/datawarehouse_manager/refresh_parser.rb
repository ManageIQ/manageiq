module ManageIQ::Providers
  class Elasticsearch::DatawarehouseManager::RefreshParser
    include CollectionsParserMixin
    def self.ems_inv_to_hashes(inventory)
      new.ems_inv_to_hashes(inventory)
    end

    def initialize
      @data = {}
      @data_index = {}
    end

    def ems_inv_to_hashes(inventory)
      get_elasticsearch_info_and_version(inventory[:info])
      get_elasticsearch_cluster_health(inventory[:health])
      get_datawarehouse_nodes(inventory[:nodes])
      @data
    end

    def self.parse_disk_usage(fs_total)
      (1 - (fs_total.available_in_bytes.to_f / fs_total.total_in_bytes.to_f)).round(4) * 100
    end

    def parse_node(id, stats)
      stats = RecursiveOpenStruct.new(stats) # for nil fields
      ip, port = stats.ip.first.split(':')
      {
        :ems_ref => id,
        :name    => stats.name,

        :host    => stats.host,
        :ip      => ip,
        :port    => port,

        :master  => stats.attributes.master == "true",
        :load    => stats.os.load_average,
        :mem     => stats.os.mem.used_percent,
        :heap    => stats.jvm.mem.heap_used_percent,
        :disk    => self.class.parse_disk_usage(stats.fs.total),
        :cpu     => stats.os.cpu_percent
      }
    end

    def get_datawarehouse_nodes(nodes)
      process_collection(nodes["nodes"], :datawarehouse_nodes) { |id, stats| parse_node(id, stats) }
      @data[:datawarehouse_nodes].each do |dwn|
        @data_index.store_path(:datawarehouse_nodes, :by_name, dwn[:name], dwn)
      end
    end

    def create_cluster_attribute(k, v,
                                 section = "cluster_attributes",
                                 source = "Elasticsearch")
      {
        :name      => k,
        :value     => v,
        :section   => section,
        :source    => source,
      }
    end

    def collect_cluster_attributes(collection, name_prefix)
      @data[:cluster_attributes] ||= []
      collection.each do |k, v|
        name = "#{name_prefix}-#{k}"
        existing_setting = @data[:cluster_attributes].find { |o| o[:name] == name }
        if existing_setting
          existing_setting[:value] = v
        else
          @data[:cluster_attributes] << create_cluster_attribute(name, v)
        end
      end
    end

    def get_elasticsearch_info_and_version(info)
      @data_index[:version] = info.delete("version")
      collect_cluster_attributes(info.merge!(@data_index[:version]), "version")
    end

    def get_elasticsearch_cluster_health(health)
      @data_index[:health] = health
      collect_cluster_attributes(@data_index[:health], "health")
    end
  end
end
