module ApplicationController::CurrentUser
  extend ActiveSupport::Concern

  included do
    helper_method :current_user,  :current_userid, :current_username
    helper_method :current_group, :current_groupid
  end

  def clear_current_user
    self.current_user = nil
  end
  protected :clear_current_user

  def current_user=(db_user)
    if db_user
      User.current_userid = db_user.userid
      session[:userid]    = db_user.userid
      session[:username]  = db_user.name
    else
      User.current_userid = nil
      session[:userid]    = nil
      session[:username]  = nil
    end
    self.current_group  = db_user.try(:current_group)
    self.current_eligible_groups = db_user.try(:miq_groups)
  end
  protected :current_user=

  def current_group=(db_group)
    session[:group] = db_group.try(:id)

    role = db_group.try(:miq_user_role)

    # Build pre-sprint 69 role name if this is an EvmRole read_only role
    session[:userrole] = role.try(:read_only?) ? role.name.split("-").last : ""
  end
  private :current_group=

  def current_eligible_groups=(eligible_groups)
    # Save an array of groups this user is eligible for, if more than 1
    eligible_groups = eligible_groups ? eligible_groups.sort_by { |g| g.description.downcase } : []
    session[:eligible_groups] = eligible_groups.length < 2 ? [] : eligible_groups.collect { |g| [g.description, g.id] }
  end
  private :current_eligible_groups=

  def current_user
    User.find_by_userid(session[:userid])
  end
  protected :current_user

  def current_userid
    session[:userid]
  end
  protected :current_userid

  def current_username
    session[:username]
  end
  protected :current_username

  def current_group
    MiqGroup.find_by_id(session[:group])
  end

  def current_groupid
    session[:group]
  end
  protected :current_groupid

  def current_userrole
    session[:userrole]
  end
  protected :current_userrole
end
