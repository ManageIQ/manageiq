class MiqApproval < ApplicationRecord
  belongs_to :approver, :polymorphic => true
  belongs_to :stamper,  :class_name => "User"
  belongs_to :miq_request

  default_value_for :state, "pending"

  def approver=(approver)
    super
    self.approver_name = approver.try(:name)
  end

  def approve(userid, reason)
    user = user_validate(userid)
    update(
      :state        => "approved",
      :reason       => reason,
      :stamper      => user,
      :stamper_name => user.name,
      :stamped_on   => Time.now.utc
    )

    # execute parent now that request is approved
    execute_approval(user)
  end

  def deny(userid, reason)
    user = user_validate(userid)
    update(
      :state        => "denied",
      :reason       => reason,
      :stamper      => user,
      :stamper_name => user.name,
      :stamped_on   => Time.now.utc
    )

    miq_request.approval_denied
  end

  def authorized?(userid)
    user = userid.kind_of?(User) ? userid : User.lookup_by_userid(userid)
    return false unless user

    return true if user.role_allows?(:identifier => "miq_request_approval") || (approver.kind_of?(User) && approver == user)

    false
  end

  def self.display_name(number = 1)
    n_('Approval', 'Approvals', number)
  end

  private

  def execute_approval(user)
    _log.info("Request: [#{miq_request.description}] has been approved by [#{user.userid}]")
    begin
      miq_request.approval_approved
    rescue => err
      _log.warn("#{err.message}, attempting to approve request: [#{miq_request.description}]")
    end
  end

  def user_validate(userid)
    user = userid.kind_of?(User) ? userid : User.lookup_by_userid(userid)
    raise "not authorized" unless authorized?(user)
    user
  end
end
