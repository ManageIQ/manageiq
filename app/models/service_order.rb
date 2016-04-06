class ServiceOrder < ActiveRecord::Base
  STATE_CART    = 'cart'.freeze
  STATE_WISH    = 'wish'.freeze
  STATE_ORDERED = 'ordered'.freeze

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

  def checkout
    _log.info("Service Order checkout for service: #{name}")

    miq_requests.each do |request|
      request.update_attributes(:process => true)
      request.call_automate_event_queue("request_created")
    end
    update_attributes(:state => STATE_ORDERED)
  end

  def self.add_to_cart(request, requester)
    _log.info("Service Order add_to_cart for Request: #{request.id} Requester: #{requester.userid}")
    service_order = ServiceOrder.find_or_create_by(:state  => STATE_CART,
                                                   :user   => requester,
                                                   :tenant => requester.current_tenant)
    service_order.miq_requests << request
    service_order
  end

  def self.order_immediately(request, requester)
    ServiceOrder.create(:state        => STATE_ORDERED,
                        :user         => requester,
                        :miq_requests => [request],
                        :tenant       => requester.current_tenant).checkout
  end
end
