require 'resource_feeder/common'
class RssFeed < ActiveRecord::Base
  include ResourceFeeder
  validates_presence_of     :name
  validates_uniqueness_of   :name

  attr_accessor :options

  acts_as_miq_taggable
  include_concern 'ImportExport'

  YML_DIR = File.join(File.expand_path(Rails.root), "product", "alerts", "rss")

  def url(host=nil)
    proto = VMDB::Config.new("vmdb").config[:webservices][:consume_protocol]
    host_url = host.nil? ? "#{proto}://localhost:3000" : "#{proto}://" + host
    "#{host_url}#{self.link}"
  end

  def generate(host=nil, local=false, proto=nil)
    proto ||= VMDB::Config.new("vmdb").config[:webservices][:consume_protocol]
    host_url = host.nil? ? "#{proto}://localhost:3000" : "#{proto}://" + host

    options = {
      :feed => {
        :title => "#{self.title}",
        :link => "#{host_url}#{self.link}",
        :description => "#{self.description}"
      },
      :item => {
        :title => Proc.new { |rec| RssFeed.eval_item_attr(self.options[:item_title], rec)},
        :description => Proc.new { |rec| RssFeed.eval_item_attr(self.options[:item_description], rec)},
        :link => Proc.new { |rec| host_url + RssFeed.eval_item_attr(self.options[:item_link], rec)},
        :pub_date => [ :created_at, :created_on, :updated_at, :updated_on ]
      }
    }

    feed = Rss.rss_feed_for(find_items, options)
    local ? feed : {:text => feed, :content_type => Mime::RSS}
  end

  def self.to_html(feed, options)
    limit = options[:limit_to_count]
    output = ""
    output << '<table class="style3">'
    output << '<tbody>'
    items = options[:limit_to_count] ? feed.items[0..options[:limit_to_count] - 1] : feed.items
    items.each_with_index do |i,idx|
      row_class = idx % 2 == 0 ? 'row0' : 'row1'
      output << "<tr class=\"#{row_class}\" onclick='window.location=\"#{i.link}\";''>"
      output << '<td>'
      output << i.title
      output << '<br/>'
      pubDate = (i.pubDate.blank? || i.pubDate == "") ? "" : format_timezone(i.pubDate, options[:tz], "raw")
      output << "Date : #{pubDate}"
      output << '</td>'
      output << '</tr>'
    end
    output << '</tbody>'
    output << '</table>'

    return output
  end

  def options
    return {} if self.name.nil?
    return @options unless @options.nil?

    file = RssFeed.yml_file_name(self.name)
    raise "no yml file found for name \"#{self.name}\"" unless File.exist?(file)
    @options = YAML.load(File.read(file)).symbolize_keys
  end

  def self.roles
    roles = []
    # RssFeed.find(:all).each {|feed|
    #   next if feed.options[:roles].nil?
    #   feed.options[:roles].split.each {|role|
    #     roles.push(role.downcase) unless roles.include?(role.downcase)
    #   }
    # }
    # Tag.tags(:ns=>"managed", :cat=>"roles").each {|t|
    #   roles.push(t.name.split("/").last)
    # }
    Tag.find(:all, :conditions => "name like '/managed/roles/%'").each {|t| roles.push(t.name.split("/").last)}
    roles
  end

  private
  def self.eval_item_attr(script, rec)
    if script.starts_with?("<script>") || script.starts_with?("<SCRIPT>")
      code = script.sub(/<script>|<SCRIPT>/, "").sub(/<\/script>|<\/SCRIPT>/, "").strip
      result = eval(code)
    else
      result = eval('"' + script + '"')
    end
    return result
  end

  def find_items
    item_class = self.options[:item_class].constantize
    case self.options[:search_method]
    when "find", nil
      if self.options[:tags] && self.options[:tags_include]
        any_or_all = self.options[:tags_include].to_sym
        items = item_class.find_tagged_with(
          any_or_all => self.options[:tags],
          :ns        => self.options[:tag_ns])
        items.order(self.options[:orderby])        if self.options[:orderby]
        items.limit(self.options[:limit_to_count]) if self.options[:limit_to_count]
        items.includes(self.options[:include])     if self.options[:include]
      else
        items = item_class.scoped
        items = items.where(self.options[:search_conditions]) if self.options[:search_conditions]
        items = items.order(self.options[:orderby])           if self.options[:orderby]
        items = items.limit(self.options[:limit_to_count])    if self.options[:limit_to_count]
        items = items.includes(self.options[:include])        if self.options[:include]
      end
      items.all
    else  # Custom find method
      items = item_class.send(self.options[:search_method].to_sym, self.name, self.options)
    end
  end

  def self.sync_from_yml_file(name)
    file = RssFeed.yml_file_name(name)
    yml = YAML.load(File.read(file)).symbolize_keys

    rss = {
      :name           => name,
      :title          => yml[:feed_title],
      :link           => yml[:feed_link],
      :description    => yml[:feed_description],
      :yml_file_mtime => File.mtime(file).utc
    }

    rec = self.find_by_name(rss[:name])
    if rec
      if rec.yml_file_mtime && rec.yml_file_mtime < rss[:yml_file_mtime]
        $log.info("MIQ(RssFeed.sync_from_yml_file) [#{rec.name}] file has been updated on disk, synchronizing with model")
        rec.update_attributes(rss)
      end
    else
      $log.info("MIQ(RssFeed.sync_from_yml_file) [#{rss[:name]}] file has been added to disk, adding to model")
      rec = self.create!(rss)
    end

    rec.tag_add(yml[:roles], {:ns => "/managed", :cat => "roles"}) unless yml[:roles].nil?
  end

  def self.yml_file_name(name)
    File.join(YML_DIR, name + ".yml")
  end

  def self.sync_from_yml_dir
    begin
      # Add missing feeds to model
      Dir.glob(File.join(YML_DIR, "*.yml")).each {|f|
        self.sync_from_yml_file(File.basename(f, ".*"))
      }

      # Remove deleted feeds from model
      RssFeed.find(:all).each {|f|
        f.destroy unless File.exist?(RssFeed.yml_file_name(f.name))
      }
    rescue => err
      $log.log_backtrace(err)
    end
  end

  def self.seed
    MiqRegion.my_region.lock do
      RssFeed.sync_from_yml_dir
    end
  end
end
