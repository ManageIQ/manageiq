require 'hamlit'
class GenericMailer < ActionMailer::Base
  include Vmdb::Logging

  def self.deliver(method, options = {})
    _log.info("starting: method: #{method} options: #{options} ")
    options[:attachment] &&= blob_to_attachment(options[:attachment])
    options[:sent_on] = Time.now

    msg = send(method, options)
    begin
      msg.deliver_now

    # catch delivery errors if raised,
    rescue Net::SMTPError => e
      invalid = []

      # attempt to resend message to recipients individually
      rcpts = [msg.to].flatten
      rcpts.each do |rcpt|
        rcpt.split(',').each do |to|
          options[:to] = to
          individual =  send(method, options)
          begin
            individual.deliver_now
          rescue Net::SMTPError
            invalid << to
          end
        end
      end

      _log.error("method: #{method} options: #{options} delivery-error #{e} recipients #{invalid}")

    # connection errors, and other if raised
    rescue => e
      _log.error("method: #{method} delivery-error: #{e} attempting to resend")

      # attempt to deliver one more time
      begin
        msg.deliver_now
      rescue => e
        _log.error("method: #{method} options: #{options} delivery-error #{e}")
      end

    end

    msg
  end

  def self.deliver_queue(method, options = {})
    return unless MiqRegion.my_region.role_assigned?('notifier')
    _log.info("starting: method: #{method} args: #{options} ")
    options[:attachment] &&= attachment_to_blob(options[:attachment])
    MiqQueue.submit_job(
      :service     => "notifier",
      :class_name  => name,
      :method_name => 'deliver',
      :args        => [method, options],
    )
  end

  def self.attachment_to_blob(attachment, attachment_filename = "evm_attachment")
    return nil if attachment.nil?

    case attachment
    when Array
      counter = 0
      attachment.collect { |a| attachment_to_blob(a, "evm_attachment_#{counter += 1}") }
    when Numeric # Blob ID
      attachment_to_blob(:attachment_id => attachment)
    when String  # Actual Body
      attachment_to_blob(:body => attachment)
    when Hash
      attachment[:filename] ||= attachment_filename
      attachment[:attachment_id] ||= begin
        blob = BinaryBlob.new(:name => "GenericMailer", :data_type => "text")
        blob.binary = attachment.delete(:body)
        blob.save
        blob.id
      end
      attachment
    else
      raise "Unexpected Attachment Class: <#{attachment.class.name}>"
    end
  end

  def self.blob_to_attachment(attachment)
    return nil if attachment.nil?

    case attachment
    when Array
      attachment.collect { |a| blob_to_attachment(a) }
    when Numeric  # Blob ID
      blob_to_attachment(:attachment_id => attachment)
    when String   # Actual Body
      blob_to_attachment(:attachment => attachment)
    when Hash
      attachment[:body] ||= begin
        blob = BinaryBlob.find(attachment.delete(:attachment_id))
        body = blob.binary unless blob.nil?
        blob.destroy unless blob.nil?
        body
      end if attachment[:attachment_id].kind_of?(Numeric)
      attachment[:filename] ||= "evm_attachment"
      attachment
    else
      raise "Unexpected Attachment Class: <#{attachment.class.name}>"
    end
  end

  def generic_notification(options)
    set_mailer_smtp
    prepare_generic_email(options)
  end

  def automation_notification(options)
    set_mailer_smtp
    prepare_generic_email(options)
  end

  def policy_action_email(options)
    set_mailer_smtp
    @miq_action_hash = options[:miq_action_hash] || {}
    prepare_generic_email(options)
  end

  def test_email(to, settings)
    set_mailer_smtp(settings)
    options = {
      :to      => to,
      :from    => settings[:from],
      :subject => "#{Vmdb::Appliance.PRODUCT_NAME} Test Email",
      :body    => "If you have received this email, your SMTP settings are correct."
    }
    prepare_generic_email(options)
  end

  def self.default_for_enable_starttls_auto
    true
  end

  def self.openssl_verify_modes
    [
      [_("None"),                 "none"],
      [_("Peer"),                 "peer"],
      [_("Client Once"),          "client_once"],
      [_("Fail If No Peer Cert"), "fail_if_no_peer_cert"]
    ]
  end

  def self.authentication_modes
    [[_("login"), "login"], [_("plain"), "plain"], [_("none"), "none"]]
  end

  protected

  def prepare_generic_email(options)
    _log.info("options: #{options.inspect}")
    options[:from] = ::Settings.smtp.from if options[:from].blank?
    @content = options[:body]
    options[:attachment] ||= []
    options[:attachment].each do |a|
      name = a[:filename]
      next if name.nil?
      attachments[name] = {:mime_type => a[:content_type], :content => a[:body]}
    end
    mail(:subject => options[:subject], :to => options[:to], :from => options[:from], :cc => options[:cc], :bcc => options[:bcc], :date => options[:sent_on])
  end

  DESTINATION_SMTP_KEYS = [:address, :port, :domain]
  AUTHENTICATION_SMTP_KEYS = [:authentication, :user_name, :password]
  OPTIONAL_SMTP_KEYS = [:enable_starttls_auto, :openssl_verify_mode]
  def set_mailer_smtp(evm_settings = nil)
    evm_settings ||= ::Settings.smtp
    am_settings =  {}

    DESTINATION_SMTP_KEYS.each { |key| am_settings[key] = evm_settings[key] }
    am_settings[:address] ||= evm_settings[:host] # vmdb.yml has key :host, ActionMailer expects :address

    evm_settings[:authentication] ||= :none
    case evm_settings[:authentication].to_s.to_sym
    when :none then           AUTHENTICATION_SMTP_KEYS.each { |key| am_settings[key] = nil }
    when :plain, :login then  AUTHENTICATION_SMTP_KEYS.each { |key| am_settings[key] = evm_settings[key] }
    else                  raise ArgumentError, "authentication value #{evm_settings[:authentication].inspect} must be one of: 'none', 'plain', 'login'"
    end

    OPTIONAL_SMTP_KEYS.each { |key| am_settings[key] = evm_settings[key] if evm_settings[key] }

    ActionMailer::Base.smtp_settings = am_settings
    log_smtp_settings = am_settings.dup
    log_smtp_settings.delete(:password)
    _log.info("Mailer settings: #{log_smtp_settings.inspect}")
    nil
  end
end
