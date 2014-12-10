#TODO: is this required?  never seemed to be used anywhere
$:.push("#{File.dirname(__FILE__)}/../../../../../lib/Scvmm")
require 'MiqScvmmInventory'

module EmsRefresh::Refreshers
  class ScvmmRefresher < BaseRefresher
    include EmsRefresherMixin

    def parse_inventory(ems, _targets)
      EmsRefresh::Parsers::Scvmm.ems_inv_to_hashes(ems, refresher_options)
    end

    def post_process_refresh_classes
      # TODO: previously this only looped over VM classes, but, since SCVMM is
      # infra, it should probably include Host, too
      [Vm]
    end
  end
end
