require_relative '../base_data'

module Openstack
  module Services
    module Image
      class Data < ::Openstack::Services::BaseData
        def images
          [{:name => "EmsRefreshSpec-Image"}]
        end

        def servers_snapshots(server_name = nil)
          servers_snapshots = {
            "EmsRefreshSpec-PoweredOn" => [{
              :name                    => "EmsRefreshSpec-PoweredOn-SnapShot"}]}

          indexed_collection_return(servers_snapshots, server_name)
        end
      end
    end
  end
end
