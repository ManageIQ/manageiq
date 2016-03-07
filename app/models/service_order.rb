class ServiceOrder < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user
  has_many :miq_requests, :dependent => :nullify

  validates :state, :inclusion => {:in => %w(wish cart ordered)}
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
    update_attributes(:state => 'ordered')
  end
end
