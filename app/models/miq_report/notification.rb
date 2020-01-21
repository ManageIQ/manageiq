module MiqReport::Notification
  def notify_user_of_report(run_on, result, options)
    userid = options[:userid]
    url = options[:email_url_prefix]

    user = User.lookup_by_userid(userid)
    from = options[:email] && !options[:email][:from].blank? ? options[:email][:from] : ::Settings.smtp.from
    to   = options[:email] ? options[:email][:to] : user.try(:email)

    msg = nil
    msg = "The system is not configured with a 'from' email address." if from.blank?
    msg = "No to: email address provided." if to.blank?

    unless msg.nil?
      _log.warn("Failed to email report because: #{msg}")
      return
    end

    send_if_empty = options.fetch_path(:email, :send_if_empty)
    send_if_empty = true if send_if_empty.nil?
    if !self.table_has_records? && !send_if_empty
      _log.info("No records found for scheduled report and :send_if_empty option is false, no Email will be sent. ")
      return
    end

    _log.info("Emailing to: #{to.inspect} report results: [#{result.name}]")

    body = notify_email_body(url, result, to)
    subject = run_on.strftime("Your report '#{title}' generated on %m/%d/%Y is ready")

    curr_tz = Time.zone # Save current time zone setting
    Time.zone = user ? user.get_timezone : MiqServer.my_server.server_timezone

    if self.table_has_records?
      attach_types = options.fetch_path(:email, :attach) || [:pdf] # support legacy schedules
      attachments = attach_types.collect do |atype|
        target = atype == :pdf ? result : self
        {
          :content_type => "application/#{atype}",
          :filename     => "#{title} #{run_on.utc.iso8601}.#{atype}",
          :body         => target.send("to_#{atype}")
        }
      end
    end

    begin
      _log.info("Queuing email user: [#{user.name}] report results: [#{result.name}] to: #{to.inspect}")
      options = {
        :to         => to,
        :from       => from,
        :subject    => subject,
        :body       => body,
        :attachment => attachments,
      }
      GenericMailer.deliver_queue(:generic_notification, options)
    rescue => err
      _log.error("Queuing email user: [#{user.name}] report results: [#{result.name}] failed with error: [#{err.class.name}] [#{err}]")
    end
    Time.zone = curr_tz # Restore original time zone setting
  end

  def notify_email_body(_url, _result, recipients)
    if self.table_has_records?
      _("Please find attached scheduled report \"%{name}\". This report was sent to: %{recipients}.") %
        {:name => name, :recipients => recipients.join(", ")}
    else
      _("No records found for scheduled report \"%{name}\"") % {:name => name}
    end
  end
end
