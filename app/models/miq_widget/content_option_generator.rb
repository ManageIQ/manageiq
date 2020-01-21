class MiqWidget::ContentOptionGenerator
  def generate(group, users, need_timezone = true)
    if group.kind_of?(MiqGroup) && !group.self_service?
      return "MiqGroup", group.description, nil, need_timezone ? timezones_for_users(users) : %w(UTC)
    else
      return "User", group.description, userids_for_users(users), nil
    end
  end

  private

  def timezones_for_users(users)
    users.collect { |user| user.try(:get_timezone) }.compact.uniq.sort
  end

  def userids_for_users(users)
    users.collect do |user|
      user.respond_to?(:userid) ? user.userid : user
    end
  end
end
