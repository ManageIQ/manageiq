RSpec.describe ServiceOrder do
  def create_request
    FactoryBot.create(:service_template_provision_request,
                       :process   => false,
                       :requester => admin)
  end

  let(:admin)         { FactoryBot.create(:user_with_group, :userid => "admin") }
  let(:user)          { FactoryBot.create(:user_with_group, :tenant => tenant) }
  let(:request)       { create_request }
  let(:request2)      { create_request }
  let(:request3)      { create_request }
  let(:service_order) do
    FactoryBot.create(:service_order_cart,
                      :state  => ServiceOrder::STATE_CART,
                      :user   => user,
                      :tenant => tenant)
  end
  let(:tenant) { Tenant.seed }

  it "doesn't access database when unchanged model is saved" do
    service_order
    expect { service_order.valid? }.not_to make_database_queries
  end

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
    service_order.update(:miq_requests => [request], :state => ServiceOrder::STATE_ORDERED)
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
    service_order.update(:state => ServiceOrder::STATE_ORDERED)
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
    service_order.update(:state => ServiceOrder::STATE_ORDERED)
    service_order.miq_requests << [request, request2]
    error_message = "Invalid operation [remove_from_cart] for Service Order in state [ordered]"
    expect { ServiceOrder.remove_from_cart(request, user) }.to raise_error(RuntimeError, error_message)
  end

  it "only allows one cart per user, tenant" do
    service_order
    expect do
      ServiceOrderCart.create!(:state => ServiceOrder::STATE_CART, :user => user, :tenant => tenant)
    end.to raise_error(ActiveRecord::RecordInvalid, /State has already been taken/)
  end

  context '#deep_copy' do
    before do
      service_order.update(:state => ServiceOrder::STATE_ORDERED)
    end

    it 'should copy the miq_requests' do
      service_order.miq_requests << [request, request2]
      service_order_copy = service_order.deep_copy
      expect(service_order_copy.miq_requests.count).to eq(2)
    end

    it 'should have its order ID in the name unless specified' do
      service_order_copy = service_order.deep_copy
      expect(service_order_copy.name).to eq("Order # #{service_order_copy.id}")
    end

    it 'should accept new attributes' do
      service_order_copy = service_order.deep_copy(:name => "foo bar")
      expect(service_order_copy.name).to eq("foo bar")
    end

    it 'should be in the cart state' do
      service_order_copy = service_order.deep_copy
      expect(service_order_copy.state).to eq(ServiceOrder::STATE_CART)
    end

    it 'should create only one new service order' do
      expect do
        service_order.deep_copy
      end.to change(ServiceOrder, :count).by(1)
    end

    it 'does not allow copying of a service order in the cart state' do
      service_order.update(:state => ServiceOrder::STATE_CART)
      expect do
        service_order.deep_copy
      end.to raise_error(RuntimeError, 'Cannot copy a service order in the cart state')
    end
  end
end
