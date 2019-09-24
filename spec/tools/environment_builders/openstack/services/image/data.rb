require_relative '../base_data'

module Openstack
  module Services
    module Image
      class Data < ::Openstack::Services::BaseData
        IMAGE_NAME = "EmsRefreshSpec-Image"

        def images
          [{
            :name => IMAGE_NAME
          }, {
            :name       => "EmsRefreshSpec-Image-Private",
            :visibility => 'private'
          }]
        end

        def images_translate_table
          {
            :is_public => :publicly_available
          }
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
