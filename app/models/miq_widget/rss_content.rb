require 'net/http'

class MiqWidget::RssContent < MiqWidget::ContentGeneration
  def self.based_on_miq_report?
    false
  end

  def external?
    resource.nil?
  end

  def generate(_user_or_group)
    opts = {:tz => timezone}

    data = if external?
             opts[:limit_to_count] = widget_options[:row_count] || 5
             external_feed
           else
             internal_feed
           end

    RssFeed.to_html(data, opts)
  end

  def internal_feed
    resource.options[:limit_to_count] = widget_options[:row_count] || 5
    SimpleRSS.parse(resource.generate)
  end

  def external_feed
    proxy = VMDB::Config.new("vmdb").config[:http_proxy]
    SimpleRSS.parse(Net::HTTP::Proxy(proxy[:host], proxy[:port], proxy[:user], proxy[:password]).get(URI.parse(widget_options[:url])))
  end
end
