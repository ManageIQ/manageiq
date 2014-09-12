require "spec_helper"

$LOAD_PATH.push(File.expand_path(File.join(File.dirname(__FILE__), %w(.. .. .. openstack))))
require 'openstack_handle/handle'
require 'fog/openstack'

describe OpenstackHandle::Handle do

  context "errors from services" do
    before do
      @original_log = $fog_log
      $fog_log = double.as_null_object
    end

    after do
      $fog_log = @original_log
    end

    it "ignores 404 errors from services" do
      openstack_svc = double('newtork_service')
      expect(openstack_svc).to receive(:security_groups).and_raise(Fog::Network::OpenStack::NotFound)

      handle = OpenstackHandle::Handle.new("dummy", "dummy", "dummy")
      expect(handle).to receive(:service_for_each_accessible_tenant).and_yield(openstack_svc)

      data = handle.accessor_for_accessible_tenants("Network", :security_groups, :id)
      data.should be_empty
    end
  end
end
