require_relative '../../base_data'

module Openstack
  module Services
    module Identity
      class Data
        class KeystoneV3 < ::Openstack::Services::BaseData
          def projects
            # TODO(lsmola) test that not enabled tenat is not throwing refresh exception
            # TOD(lsmola) test that tenant without admin user assigned is not throwing refresh
            # exception
            [{:name => "admin", :enabled => true},
             {:name => "EmsRefreshSpec-Project", :enabled => true},
             {:name => "EmsRefreshSpec-Project2", :enabled => true},
             {:name => "EmsRefreshSpec-Project-No-Admin-Role", :enabled => true},
             {:name => "EmsRefreshSpec-Project-parent-test-1", :enabled => true,
              :__parent_name => "EmsRefreshSpec-Project2"},
             {:name => "EmsRefreshSpec-Project-parent-test-2", :enabled => true,
              :__parent_name => "EmsRefreshSpec-Project-parent-test-1"},
             {:name => "EmsRefreshSpec-Project-parent-test-3", :enabled => true,
              :__parent_name => "EmsRefreshSpec-Project-parent-test-2"}
            ]
          end

          def roles
            %w(admin heat_stack_owner SwiftOperator)
          end
        end
      end
    end
  end
end
