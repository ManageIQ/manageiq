module ManageiqForeman
  class Connection
    CLASSES = {
      :config_templates  => ForemanApi::Resources::ConfigTemplate,
      :home              => ForemanApi::Resources::Home,
      :hostgroups        => ForemanApi::Resources::Hostgroup,
      :hosts             => ForemanApi::Resources::Host,
      :media             => ForemanApi::Resources::Medium,
      :operating_systems => ForemanApi::Resources::OperatingSystem,
      :ptables           => ForemanApi::Resources::Ptable,
      :subnets           => ForemanApi::Resources::Subnet,
    }

    attr_accessor :connection_attrs

    def initialize(connection_attrs)
      @connection_attrs = connection_attrs
    end

    def all(method, filter = {})
      page = 0
      all = []

      loop do
        small = public_send(method, {:page => (page += 1), :per_page => 50}.merge(filter))
        all += small.to_a
        break if small.empty? || all.size >= small.total
      end
      PagedResponse.new(all)
    end

    # filter:
    #   accepts "page" => 2, "per_page" => 50, "search" => "field=value", "value"
    def hosts(filter = {})
      fetch(:hosts, :index, filter)
    end

    def denormalized_hostgroups(filter = {})
      denormalize_ancestors!(all(:hostgroups, filter))
    end

    def hostgroups(filter = {})
      fetch(:hostgroups, :index, filter)
    end

    # expecting "id" => #
    def operating_system(filter)
      fetch(:operating_systems, :show, filter)
    end

    def operating_systems(filter = {})
      fetch(:operating_systems, :index, filter)
    end

    def operating_system_details(filter = {})
      operating_systems(filter).map! { |os| operating_system("id" => os["id"]).first }
    end

    def media(filter = {})
      fetch(:media, :index, filter)
    end

    def ptables(filter = {})
      fetch(:ptables, :index, filter)
    end

    def config_templates(filter = {})
      fetch(:config_templates, :index, filter)
    end

    def subnets(filter = {})
      fetch(:subnets, :index, filter)
    end

    private

    def fetch(resource, action = :index, filter = {})
      PagedResponse.new(raw(resource).send(action, filter).first)
    end

    def denormalize_ancestors!(records)
      records.each do |record|
        ancestor_ids(record["ancestry"]).reverse.each do |ancestor_id|
          ancestor = records.detect { |r| r["id"] == ancestor_id }
          ancestor.each_pair { |n, v| record[n] ||= v unless v.nil? } if ancestor
        end
      end
      records
    end

    def ancestor_ids(str)
      (str || "").split("/").collect(&:to_i)
    end

    def raw(resource)
      CLASSES[resource].new(connection_attrs)
    end
  end
end
