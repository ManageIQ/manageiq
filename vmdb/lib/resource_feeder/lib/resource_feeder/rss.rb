require 'resource_feeder/common'

module ResourceFeeder
  module Rss
    include ResourceFeeder::Common
    extend self

    def render_rss_feed_for(resources, options = {})
      render :text => rss_feed_for(resources, options), :content_type => Mime::RSS
    end

    def rss_feed_for(resources, options = {})
      require 'builder'
      xml = Builder::XmlMarkup.new(:indent => 2)

      options[:feed]       ||= {}
      options[:item]       ||= {}
      options[:url_writer] ||= self

      if options[:class] || resources.first
        klass      = options[:class] || resources.first.class
        new_record = klass.new
      else
        options[:feed] = { :title => "Empty", :link => "http://example.com" }
      end
      use_content_encoded = options[:item].has_key?(:content_encoded)

      options[:feed][:title]    ||= klass.name.pluralize
      options[:feed][:link]     ||= SimplyHelpful::PolymorphicRoutes.polymorphic_url(new_record, options[:url_writer])
      options[:feed][:language] ||= "en-us"
      options[:feed][:ttl]      ||= "40"

      options[:item][:title]           ||= [ :title, :subject, :headline, :name ]
      options[:item][:description]     ||= [ :description, :body, :content ]
      options[:item][:pub_date]        ||= [ :updated_at, :updated_on, :created_at, :created_on ]

      resource_link = lambda { |r| SimplyHelpful::PolymorphicRoutes.polymorphic_url(r, options[:url_writer]) }

      rss_root_attributes = { :version => 2.0 }
      rss_root_attributes.merge!("xmlns:content" => "http://purl.org/rss/1.0/modules/content/") if use_content_encoded

      xml.instruct!

      xml.rss(rss_root_attributes) do
        xml.channel do
          xml.title(options[:feed][:title])
          xml.link(options[:feed][:link])
          xml.description(options[:feed][:description]) if options[:feed][:description]
          xml.language(options[:feed][:language])
          xml.ttl(options[:feed][:ttl])

          for resource in resources
            xml.item do
              xml.title(call_or_read(options[:item][:title], resource))
              xml.description(call_or_read(options[:item][:description], resource))
              if use_content_encoded then
                xml.content(:encoded) { xml.cdata!(call_or_read(options[:item][:content_encoded], resource)) }
              end
              pubDate = call_or_read(options[:item][:pub_date], resource)
              xml.pubDate(pubDate.to_s(:rfc822)) unless pubDate == nil
              xml.guid(call_or_read(options[:item][:guid] || options[:item][:link] || resource_link, resource))
              xml.link(call_or_read(options[:item][:link] || options[:item][:guid] || resource_link, resource))
            end
          end
        end
      end
    end
  end
end
