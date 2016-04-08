class ServiceOrder < ActiveRecord::Base
  STATE_CART    = 'cart'.freeze
  STATE_WISH    = 'wish'.freeze
  STATE_ORDERED = 'ordered'.freeze

  before_destroy :destroy_unprocessed_requests
  belongs_to :tenant
  belongs_to :user
  has_many :miq_requests, :dependent => :nullify

  validates :state, :inclusion => {:in => [STATE_WISH, STATE_CART, STATE_ORDERED]}
  validates :state, :presence => true
  validates :name, :presence => true, :on => :update

  before_create :assign_user
  after_create  :create_order_name

  def assign_user
    self.user      ||= User.current_user
    self.tenant    ||= user.try(:current_tenant)
    self.user_name = user.try(:name)
  end

  def create_order_name
    update_attributes(:name => "Order # #{id}") if name.blank?
  end

  def ordered?
    state == STATE_ORDERED
  end

  def checkout
    raise "Invalid operation [checkout] for Service Order in state [#{state}]" if ordered?
    _log.info("Service Order checkout for service: #{name}")
    process_checkout(miq_requests)
    update_attributes(:state => STATE_ORDERED)
  end

  def checkout_immediately
    _log.info("Service Order checkout immediately for service: #{name}")
    process_checkout(miq_requests)
    update_attributes(:state => STATE_ORDERED)
  end

  def process_checkout(miq_requests)
    miq_requests.each do |request|
      request.update_attributes(:process => true)
      request.call_automate_event_queue("request_created")
    end
  end

  def clear
    raise "Invalid operation [clear] for Service Order in state [#{state}]" if ordered?
    _log.info("Service Order clear for service: #{name}")
    destroy_unprocessed_requests
  end

  def self.add_to_cart(request, requester)
    _log.info("Service Order add_to_cart for Request: #{request.id} Requester: #{requester.userid}")
    service_order = ServiceOrder.find_or_create_by(:state  => STATE_CART,
                                                   :user   => requester,
                                                   :tenant => requester.current_tenant)
    service_order.miq_requests << request
    service_order
  end

  def self.remove_from_cart(request, requester)
    service_order = request.service_order
    err_msg = "Invalid operation [remove_from_cart] for Service Order in state [#{service_order.state}]"
    raise err_msg if service_order.ordered?

    _log.info("Service Order remove_from_cart for Request: #{request.id} Service Order: #{service_order.id} Requester: #{requester.userid}")
    request.destroy
  end

  def self.order_immediately(request, requester)
    ServiceOrder.create(:state        => STATE_ORDERED,
                        :user         => requester,
                        :miq_requests => [request],
                        :tenant       => requester.current_tenant).checkout_immediately
  end

  private

  def destroy_unprocessed_requests
    return if ordered?
    miq_requests.destroy_all
  end
end
