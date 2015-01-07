$:.push("#{File.dirname(__FILE__)}/../../../../../lib/kvm")
require 'MiqKvmInventory'

module EmsRefresh::Refreshers
  class KvmRefresher < BaseRefresher
    include RefresherRelatsMixin
    include EmsRefresherMixin

    def parse_inventory(ems, _targets)
      @kvm = MiqKvmInventory.new(ems.ipaddress, *ems.auth_user_pwd)
      @kvm.refresh
    end

    def save_inventory(ems, targets, hashes)
      EmsRefresh.save_inventory(ems, hashes, targets[0])
    end

    def post_refresh_ems_cleanup(_ems, _targets)
      @kvm.disconnect if @kvm
    end
  end
end
