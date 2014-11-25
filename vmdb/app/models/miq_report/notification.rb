module MiqReport::Notification
  def notify_user_of_report(run_on, result, options)
    userid = options[:userid]
    url = options[:email_url_prefix]

    user = User.find_by_userid(userid)
    from = options[:email] && !options[:email][:from].blank? ? options[:email][:from] : VMDB::Config.new("vmdb").config[:smtp][:from]
    to   = options[:email] ? options[:email][:to] : (user ? user.email : nil)

    msg = nil
    msg = "The system is not configured with a 'from' email address." if from.blank?
    msg = "No to: email address provided." if to.blank?

    unless msg.nil?
      $log.warn("MIQ(MiqReport-notify_users_of_report user: Failed to email report because: #{msg}")
      return
    end

    send_if_empty = options.fetch_path(:email, :send_if_empty)
    send_if_empty = true if send_if_empty.nil?
    if !self.table_has_records? && !send_if_empty
      $log.info("MIQ(MiqReport-notify_users_of_report) No records found for scheduled report and :send_if_empty option is false, no Email will be sent. ")
      return
    end

    $log.info("MIQ(MiqReport-notify_users_of_report) Emailing to: #{to.inspect} report results: [#{result.name}]")

    body = notify_email_body(url, result, to)
    subject = run_on.strftime("Your report '#{self.title}' generated on %m/%d/%Y is ready")

    curr_tz = Time.zone # Save current time zone setting
    Time.zone = (user ? user.settings.fetch_path(:display, :timezone) : nil) || MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC"

    if self.table_has_records?
      attach_types = options.fetch_path(:email, :attach) || [:pdf] # support legacy schedules
      attachments = attach_types.collect do |atype|
        target = atype == :pdf ? result : self
        {
          :content_type => "application/#{atype}",
          :filename     => "#{self.title} #{run_on.utc.iso8601}.#{atype}",
          :body         => target.send("to_#{atype}")
        }
      end
    end

    # Avoid ActionMailer bug where the email headers get corrupted when the total length in bytes of all the recipients exceeds approx 150 bytes.
    # When this happens, the addresses on the end spill over into the headers and cause the content and mime information to be ignored.
    #
    # Split recipient list into groups whose total length in bytes is around 100 bytes or the configured limit
    cut_off = VMDB::Config.new("vmdb").config.fetch_path(:smtp, :recipient_address_byte_limit) || 100
    sub_group = []
    grouped_tos = to.uniq.inject([]) do |g,t|
      sub_group << t
      if sub_group.join.length >= cut_off || to.index(t) == (to.length - 1)
        g << sub_group
        sub_group = []
      end
      g
    end
    #

    begin
      grouped_tos.each do |group_of_tos|
        $log.info("MIQ(MiqReport-notify_users_of_report) Queuing email user: [#{user.name}] report results: [#{result.name}] to: #{group_of_tos.inspect}")
        options = {
          :to          => group_of_tos,
          :from        => from,
          :subject     => subject,
          :body        => body,
          :attachment  => attachments,
        }
        GenericMailer.deliver_queue(:generic_notification, options)
      end
    rescue => err
      $log.error("MIQ(MiqReport-notify_users_of_report) Queuing email user: [#{user.name}] report results: [#{result.name}] failed with error: [#{err.class.name}] [#{err}]")
    end
    Time.zone = curr_tz # Restore original time zone setting
  end


  def notify_email_body(url, result, recipients)
    if self.table_has_records?
      "Please find attached scheduled report \"#{name}\". This report was sent to: #{recipients.join(", ")}."
    else
      "No records found for scheduled report \"#{name}\""
    end
  end
end
