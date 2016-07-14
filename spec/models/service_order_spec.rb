describe ServiceOrder do
  def create_request
    FactoryGirl.create(:service_template_provision_request,
                       :process   => false,
                       :requester => admin)
  end

  let(:admin)         { FactoryGirl.create(:user_with_group, :userid => "admin") }
  let(:user)          { FactoryGirl.create(:user_with_group, :tenant => tenant) }
  let(:request)       { create_request }
  let(:request2)      { create_request }
  let(:request3)      { create_request }
  let(:service_order) do
    FactoryGirl.create(:service_order, :state  => ServiceOrder::STATE_CART,
                                       :user   => user,
                                       :tenant => tenant)
  end
  let(:tenant) { Tenant.seed }

  it "should add an miq_request properly" do
    expect request.service_order == service_order.id
    expect request.process == false
    expect(service_order.state).to eq(ServiceOrder::STATE_CART)
  end

  it "should add multiple miq_requests properly" do
    [request, request2, request3].each do |r|
      expect r.service_order == service_order.id
      expect r.process == false
    end
    expect(service_order.state).to eq(ServiceOrder::STATE_CART)
    expect service_order.miq_requests.count == MiqRequest.count
  end

  it "should checkout properly for cart service order" do
    service_order.miq_requests << [request, request2, request3]
    service_order.checkout
    expect(service_order).to be_ordered
    expect(service_order.placed_at).not_to be_nil
  end

  it "should raise an error on checkout for ordered service order" do
    service_order.update_attributes(:miq_requests => [request], :state => ServiceOrder::STATE_ORDERED)
    error_message = "Invalid operation [checkout] for Service Order in state [ordered]"
    expect { service_order.checkout }.to raise_error(RuntimeError, error_message)
  end

  it "should allow you to order immediately" do
    ServiceOrder.order_immediately(request, user)
    expect(request.service_order.miq_requests.count).to eq(1)
  end

  it "should clear the cart properly" do
    service_order.miq_requests << [request, request2]
    expect(service_order.miq_requests.count).to eq(2)
    service_order.clear
    expect(service_order.miq_requests.count).to eq(0)
  end

  it "should clear the cart properly when the service order is destroyed" do
    service_order.miq_requests << [request, request2]
    expect(service_order.miq_requests.count).to eq(2)
    service_order.destroy
    expect(ServiceOrder.count).to eq(0)
    expect(MiqRequest.count).to eq(0)
  end

  it "should raise an error while trying to clear the cart on an ordered service order" do
    service_order.update_attributes(:state => ServiceOrder::STATE_ORDERED)
    service_order.miq_requests << request
    error_message = "Invalid operation [clear] for Service Order in state [ordered]"
    expect { service_order.clear }.to raise_error(RuntimeError, error_message)
  end

  it "should add to cart properly with an existing user service_order" do
    service_order
    expect(ServiceOrder.add_to_cart(request, user)).to eq(service_order)
    expect(service_order.miq_requests.first).to eq(request)
  end

  it "should add to cart properly creating a new admin service_order" do
    so = ServiceOrder.add_to_cart(request, admin)
    expect(so).not_to eq(service_order)
    expect(so.miq_requests.first).to eq(request)
  end

  it "should remove from cart properly" do
    service_order.miq_requests << [request, request2]
    expect(service_order.miq_requests.count).to eq(2)
    ServiceOrder.remove_from_cart(request, user)
    expect(service_order.miq_requests.count).to eq(1)
  end

  it "should raise an error while trying to remove from cart on ordered service order" do
    service_order.update_attributes(:state => ServiceOrder::STATE_ORDERED)
    service_order.miq_requests << [request, request2]
    error_message = "Invalid operation [remove_from_cart] for Service Order in state [ordered]"
    expect { ServiceOrder.remove_from_cart(request, user) }.to raise_error(RuntimeError, error_message)
  end
end
