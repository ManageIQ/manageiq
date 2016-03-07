describe ServiceOrder do
  let(:admin)         { FactoryGirl.create(:user_admin) }
  let(:service_order) { FactoryGirl.create(:service_order, :state => 'cart') }
  let(:user_obj)      { FactoryGirl.create(:user) }
  let(:ems)           { FactoryGirl.create(:ems_vmware) }
  let(:vm)            { FactoryGirl.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx") }
  let(:vm_template)   { FactoryGirl.create(:template_vmware, :name => "template1", :ext_management_system => ems) }
  let(:request) do
    FactoryGirl.create(:service_template_provision_request,
                       :description => 'Service Request',
                       :requester   => admin,
                       :options     => {:service_order_id => service_order.id})
  end
  let(:request2) do
    FactoryGirl.create(:service_template_provision_request,
                       :description => 'Service Request',
                       :requester   => admin,
                       :options     => {:service_order_id => service_order.id})
  end
  let(:request3) do
    FactoryGirl.create(:service_template_provision_request,
                       :description => 'Service Request',
                       :requester   => admin,
                       :options     => {:service_order_id => service_order.id})
  end

  it "should add an miq_request properly" do
    request

    expect request.service_order == service_order.id
    expect request.process == false
    expect(ServiceOrder.first).to have_attributes(
      :name  => 'service order',
      :state => 'cart'
    )
  end

  it "should add multiple miq_requests properly" do
    [request, request2, request3].each do |r|
      expect r.service_order == service_order.id
      expect r.process == false
    end
    service_order = ServiceOrder.first
    expect(service_order).to have_attributes(
      :name  => 'service order',
      :state => 'cart'
    )
    expect service_order.miq_requests.count == MiqRequest.count
  end

  it "should checkout properly" do
    r1 = request
    r2 = request2
    r3 = request3
    service_order.checkout
    [r1, r2, r3].each do |r|
      r.reload
      expect r.service_order == service_order.id
      expect r.process == true
    end
    expect(ServiceOrder.first).to have_attributes(
      :name  => 'service order',
      :state => 'ordered'
    )
  end
end
