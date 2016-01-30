require_relative '../../base_data'

module Openstack
  module Services
    module Identity
      class Data
        class KeystoneV2 < ::Openstack::Services::BaseData
          def projects
            # TODO(lsmola) test that not enabled tenat is not throwing refresh exception
            # TOD(lsmola) test that tenant without admin user assigned is not throwing refresh
            # exception
            [{:name => "admin", :enabled => true},
             {:name => "EmsRefreshSpec-Project", :enabled => true},
             {:name => "EmsRefreshSpec-Project2", :enabled => true},
             {:name => "EmsRefreshSpec-Project-No-Admin-Role", :enabled => true}]
          end

          def roles
            %w(admin heat_stack_owner)
          end
        end
      end
    end
  end
end
