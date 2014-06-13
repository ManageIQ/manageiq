class MiqApproval < ActiveRecord::Base
  belongs_to :approver, :polymorphic => true
  belongs_to :stamper,  :class_name => "User"
  belongs_to :miq_request

  validates_presence_of :approver

  include ReportableMixin

  default_value_for :state, "pending"

  before_create :set_approver_delegates

  def set_approver_delegates
    if self.approver
      self.approver_type = self.approver.class.name
      self.approver_name = self.approver.name
    end
  end

  def approve(userid, reason)
    user = User.find_by_userid(userid)
    raise "not authorized" unless self.authorized?(user)
    self.update_attributes(:state => "approved", :reason => reason, :stamper => user, :stamper_name => user.name, :stamped_on => Time.now.utc)

    # execute parent now that request is approved
    $log.info("MIQ(MiqApproval.approve) Request: [#{self.miq_request.description}] has been approved by [#{userid}]")
    begin
      self.miq_request.approval_approved
    rescue => err
      $log.warn("MIQ(MiqApproval.approve) #{err.message}, attempting to approve request: [#{self.miq_request.description}]")
    end
  end

  def deny(userid, reason)
    user = User.find_by_userid(userid)
    raise "not authorized" unless self.authorized?(user)
    self.update_attributes(:state => "denied", :reason => reason, :stamper => user, :stamper_name => user.name, :stamped_on => Time.now.utc)
    self.miq_request.approval_denied
  end

  def authorized?(userid)
    user = userid.kind_of?(User) ? userid : User.find_by_userid(userid)
    return false unless user
    return false unless self.approver

    return true if user.role_allows?(:identifier=>"miq_request_approval")
    return true if self.approver.kind_of?(User) && self.approver == user
    return true if self.approver.kind_of?(UiTaskSet) && self.approver == user.role

    return false
  end
end
