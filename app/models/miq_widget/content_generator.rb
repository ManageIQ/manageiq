class MiqWidget::ContentGenerator
  include Vmdb::Logging

  def generate(widget, klass, group_description, userids, timezones = nil)
    raise "Unsupported: #{klass}" if unsupported_class?(klass)

    expected_count = determine_expected_count(klass, group_description, userids, timezones)
    result = determine_content(klass, group_description, userids, timezones, widget)

    if result.length != expected_count
      name = klass == "MiqGroup" ? "Group: #{group_description}" : userids.inspect
      error_message = "Expected #{expected_count} contents, received #{result.length} contents for #{name[0, 256]}"
      _log.error("#{widget.log_prefix} #{error_message}")
      raise MiqException::Error,
            "Expected %{number} contents, received %{length} contents for %{name}" % {:number => expected_count,
                                                                                      :length => result.length,
                                                                                      :name   => name[0, 256]}
    end

    result
  end

  private

  def determine_content(klass, group_description, userids, timezones, widget)
    group = find_group_or_raise(group_description, widget)
    case klass
    when "MiqGroup"
      timezones.collect { |timezone| widget.generate_one_content_for_group(group, timezone) }.compact
    when "User"
      widget.delete_legacy_contents_for_group(group)
      userids.collect { |userid| widget.generate_one_content_for_user(group, userid) }.compact
    end
  end

  def determine_expected_count(klass, _group_description, userids, timezones)
    case klass
    when "MiqGroup"
      timezones.length
    when "User"
      userids.length
    end
  end

  def find_group_or_raise(group_description, widget)
    group = MiqGroup.in_my_region.find_by(:description => group_description)
    if group.nil?
      error_message = "MiqGroup #{group_description} was not found"
      _log.error("#{widget.log_prefix} #{error_message}")
      raise MiqException::Error, _("MiqGroup %{description} was not found") % {:description => group_description}
    end

    group
  end

  def unsupported_class?(klass)
    !["MiqGroup", "User"].include?(klass)
  end
end
