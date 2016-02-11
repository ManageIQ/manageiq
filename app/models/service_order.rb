class ServiceOrder < ActiveRecord::Base
  belongs_to :tenant
  belongs_to :user
  has_many :miq_requests, :dependent => :nullify

  validates :state, :inclusion => {:in => %w(wish cart ordered)}
  validates :name, :presence => true
  validates :state, :presence => true

  before_create :assign_user_name

  def assign_user_name
    self.user_name = user.try(:name)
  end
end
