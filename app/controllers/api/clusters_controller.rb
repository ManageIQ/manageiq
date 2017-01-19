module Api
  class ClustersController < BaseController
    include Subcollections::Policies
    include Subcollections::PolicyProfiles
    include Subcollections::Tags

    def options
      render_options(:clusters, :node_types => EmsCluster.node_types)
    end
  end
end
