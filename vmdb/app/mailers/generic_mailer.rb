class GenericMailer < ActionMailer::Base

  def self.deliver(method, options = {})
    $log.info("MIQ(GenericMailer-deliver) starting: method: #{method} options: #{options} ")
    options[:attachment] &&= self.blob_to_attachment(options[:attachment])
    options[:sent_on] = Time.now

    msg = self.send(method,options)
    begin
      msg.deliver

    # catch delivery errors if raised,
    rescue Net::SMTPError => e
      invalid = []

      # attempt to resend message to recipients individually
      rcpts = [msg.to].flatten
      rcpts.each do |rcpt|
        rcpt.split(',').each do |to|
          options.merge! :to => to
          individual =  self.send(method, options)
          begin
            individual.deliver
          rescue Net::SMTPError
            invalid << to
          end
        end
      end

      $log.error("MIQ(GenericMailer-deliver) method: #{method} options: #{options} delivery-error #{e} recipients #{invalid}")

    # connection errors, and other if raised
    rescue => e
      $log.error("MIQ(GenericMailer-deliver) method: #{method} delivery-error: #{e} attempting to resend")

      # attempt to deliver one more time
      begin
        msg.deliver
      rescue => e
        $log.error("MIQ(GenericMailer-deliver) method: #{method} options: #{options} delivery-error #{e}")
      end

    end

    msg
  end

  def self.deliver_queue(method, options = {})
    $log.info("MIQ(GenericMailer-deliver_queue) starting: method: #{method} args: #{options} ")
    options[:attachment] &&= self.attachment_to_blob(options[:attachment])
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => 'deliver',
      :role        => 'notifier',
      :args        => [method, options],
      :zone        => nil
    )
  end

  def self.attachment_to_blob(attachment, attachment_filename = "evm_attachment")
    return nil if attachment.nil?

    case attachment
    when Array
      counter = 0
      attachment.collect { |a| self.attachment_to_blob(a, "evm_attachment_#{counter += 1}") }
    when Numeric # Blob ID
      self.attachment_to_blob( {:attachment_id => attachment})
    when String  # Actual Body
      self.attachment_to_blob({ :body => attachment })
    when Hash
      attachment[:filename]      ||= attachment_filename
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
      attachment.collect { |a| self.blob_to_attachment(a) }
    when Numeric  # Blob ID
      self.blob_to_attachment( { :attachment_id => attachment } )
    when String   # Actual Body
      self.blob_to_attachment( { :attachment => attachment } )
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
      :subject => "#{I18n.t("product.name")} Test Email",
      :body    => "If you have received this email, your SMTP settings are correct."
    }
    prepare_generic_email(options)
  end

  def self.default_for_enable_starttls_auto
    true
  end

  def self.openssl_verify_modes
    %w{none peer client_once fail_if_no_peer_cert}
  end

  def self.authentication_modes
    %w{login plain none}
  end

  protected

  def prepare_generic_email(options)
    $log.info("MIQ(GenericMailer#prepare_generic_email) options: #{options.inspect}")
    options[:from] = VMDB::Config.new("vmdb").config.fetch_path(:smtp, :from) if options[:from].blank?
    @content = options[:body]
    options[:attachment] ||= []
    options[:attachment].each do |a|
      name = a[:filename]
      next if name.nil?
      attachments[name] = { :mime_type => a[:content_type], :content => a[:body] }
    end
    mail(:subject => options[:subject], :to => options[:to], :from => options[:from], :cc => options[:cc], :bcc => options[:bcc], :date => options[:sent_on])
  end

  DESTINATION_SMTP_KEYS = [:address, :port, :domain]
  AUTHENTICATION_SMTP_KEYS = [:authentication, :user_name, :password]
  OPTIONAL_SMTP_KEYS = [:enable_starttls_auto, :openssl_verify_mode]
  def set_mailer_smtp(evm_settings = nil)
    evm_settings ||= VMDB::Config.new("vmdb").config[:smtp]
    am_settings =  {}

    DESTINATION_SMTP_KEYS.each { |key| am_settings[key] = evm_settings[key] }
    am_settings[:address] ||= evm_settings[:host] # vmdb.yml has key :host, ActionMailer expects :address

    evm_settings[:authentication] ||= :none
    case evm_settings[:authentication].to_s.to_sym
    when :none;           AUTHENTICATION_SMTP_KEYS.each { |key| am_settings[key] = nil }
    when :plain, :login;  AUTHENTICATION_SMTP_KEYS.each { |key| am_settings[key] = evm_settings[key] }
    else                  raise ArgumentError, "authentication value #{evm_settings[:authentication].inspect} must be one of: 'none', 'plain', 'login'"
    end

    OPTIONAL_SMTP_KEYS.each { |key| am_settings[key] = evm_settings[key] if evm_settings.has_key?(key) }

    ActionMailer::Base.smtp_settings = am_settings
    log_smtp_settings = am_settings.dup
    log_smtp_settings.delete(:password)
    $log.info("MIQ(GenericMailer#set_mailer_smtp) Mailer settings: #{log_smtp_settings.inspect}")
    nil
  end
end
