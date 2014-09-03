class MiqApproval < ActiveRecord::Base
  belongs_to :approver, :polymorphic => true
  belongs_to :stamper,  :class_name => "User"
  belongs_to :miq_request

  include ReportableMixin

  default_value_for :state, "pending"

  def approver=(approver)
    super
    self.approver_name = approver.try(:name)
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

    return true if user.role_allows?(:identifier => "miq_request_approval")
    return true if self.approver.kind_of?(User) && self.approver == user

    return false
  end
end
