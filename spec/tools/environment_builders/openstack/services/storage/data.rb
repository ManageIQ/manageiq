require_relative '../base_data'

module Openstack
  module Services
    module Storage
      class Data < ::Openstack::Services::BaseData
        def directory_name_1
          "dir_1"
        end

        def directories
          [
            {:key => directory_name_1},
            {:key => "dir_2"},
            {:key => "dir_3"}
          ]
        end

        def files(directory_name = nil)
          files = {
            directory_name_1 => [
              {:key => "file_1", :__body => "file_1 body"},
              {:key => "file_2", :__body => "file_2 body"},
              {:key => "file_3", :__body => "file_3 body"},
            ]
          }

          indexed_collection_return(files, directory_name)
        end
      end
    end
  end
end
