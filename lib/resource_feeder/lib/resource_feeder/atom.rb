require 'resource_feeder/common'

module ResourceFeeder
  module Atom
    include ResourceFeeder::Common
    extend self

    def render_atom_feed_for(resources, options = {})
      render :text => atom_feed_for(resources, options), :content_type => Mime::ATOM
    end

    def atom_feed_for(resources, options = {})
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

      options[:feed][:title] ||= klass.name.pluralize
      options[:feed][:id]    ||= "tag:#{request.host_with_port}:#{klass.name.pluralize}"
      options[:feed][:link]  ||= SimplyHelpful::PolymorphicRoutes.polymorphic_url(new_record, options[:url_writer])

      options[:item][:title]       ||= [ :title, :subject, :headline, :name ]
      options[:item][:description] ||= [ :description, :body, :content ]
      options[:item][:pub_date]    ||= [ :updated_at, :updated_on, :created_at, :created_on ]
      options[:item][:author]      ||= [ :author, :creator ]

      resource_link = lambda { |r| SimplyHelpful::PolymorphicRoutes.polymorphic_url(r, options[:url_writer]) }

      xml.instruct!
      xml.feed "xml:lang" => "en-US", "xmlns" => 'http://www.w3.org/2005/Atom' do
        xml.title(options[:feed][:title])
        xml.id(options[:feed][:id])
        xml.link(:rel => 'alternate', :type => 'text/html', :href => options[:feed][:link])
        xml.link(:rel => 'self', :type => 'application/atom+xml', :href => options[:feed][:self]) if options[:feed][:self]
        xml.subtitle(options[:feed][:description]) if options[:feed][:description]

        for resource in resources
          published_at = call_or_read(options[:item][:pub_date], resource)

          xml.entry do
            xml.title(call_or_read(options[:item][:title], resource))
            xml.content(call_or_read(options[:item][:description], resource), :type => 'html')
            xml.id("tag:#{request.host_with_port},#{published_at.xmlschema}:#{call_or_read(options[:item][:guid] || options[:item][:link] || resource_link, resource)}")
            xml.published(published_at.xmlschema)
            xml.updated((resource.respond_to?(:updated_at) ? call_or_read(options[:item][:pub_date] || :updated_at, resource) : published_at).xmlschema)
            xml.link(:rel => 'alternate', :type => 'text/html', :href => call_or_read(options[:item][:link] || options[:item][:guid] || resource_link, resource))

            if author = call_or_read(options[:item][:author], resource)
              xml.author do
                xml.name()
              end
            end
          end
        end
      end
    end
  end
end
