require 'resource_feeder/common'
class RssFeed < ApplicationRecord
  include ResourceFeeder
  validates_presence_of     :name
  validates_uniqueness_of   :name

  attr_accessor :options

  acts_as_miq_taggable
  include_concern 'ImportExport'

  YML_DIR = File.join(File.expand_path(Rails.root), "product", "alerts", "rss")

  def url(host = nil)
    proto = VMDB::Config.new("vmdb").config[:webservices][:consume_protocol]
    host_url = host.nil? ? "#{proto}://localhost:3000" : "#{proto}://" + host
    "#{host_url}#{link}"
  end

  def generate(host = nil, local = false, proto = nil, user_or_group = nil)
    proto ||= VMDB::Config.new("vmdb").config[:webservices][:consume_protocol]
    host_url = host.nil? ? "#{proto}://localhost:3000" : "#{proto}://" + host

    options = {
      :feed => {
        :title       => title.to_s,
        :link        => "#{host_url}#{link}",
        :description => description.to_s
      },
      :item => {
        :title       => proc { |rec| RssFeed.eval_item_attr(self.options[:item_title], rec) },
        :description => proc { |rec| RssFeed.eval_item_attr(self.options[:item_description], rec) },
        :link        => proc { |rec| host_url + RssFeed.eval_item_attr(self.options[:item_link], rec) },
        :pub_date    => [:created_at, :created_on, :updated_at, :updated_on]
      }
    }

    rbac_options = {}
    if user_or_group
      user_or_group_key = user_or_group.kind_of?(User) ? :user : :miq_group
      rbac_options[user_or_group_key] = user_or_group
    end

    filtered_items = Rbac::Filterer.filtered(find_items, rbac_options)
    feed = Rss.rss_feed_for(filtered_items, options)
    local ? feed : {:text => feed, :content_type => Mime[:rss]}
  end

  def self.to_html(feed, options)
    limit = options[:limit_to_count]
    output = ""
    output << '<table class="table table-striped table-bordered table-hover">'
    output << '<tbody>'
    items = options[:limit_to_count] ? feed.items[0..options[:limit_to_count] - 1] : feed.items
    items.each_with_index do |i, _idx|
      output << "<tr onclick='window.location=\"#{i.link}\";'>"
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

    output
  end

  def options
    return {} if name.nil?
    return @options unless @options.nil?

    file = RssFeed.yml_file_name(name)
    raise _("no yml file found for name \"%{name}\"") % {:name => name} unless File.exist?(file)
    @options = YAML.load(File.read(file)).symbolize_keys
  end

  def self.roles
    Tag.where("name like '/managed/roles/%'").pluck(:name).collect { |n| n.split("/").last }
  end

  private

  def self.eval_item_attr(script, rec)
    _ = rec # used by eval
    if script.starts_with?("<script>", "<SCRIPT>")
      code = script.sub(/<script>|<SCRIPT>/, "").sub(/<\/script>|<\/SCRIPT>/, "").strip
      result = eval(code)
    else
      result = eval('"' + script + '"')
    end
    result
  end

  def find_items
    item_class = options[:item_class].constantize
    case options[:search_method]
    when "find", nil
      if options[:tags] && options[:tags_include]
        any_or_all = options[:tags_include].to_sym
        items = item_class.find_tagged_with(
          any_or_all => options[:tags],
          :ns        => options[:tag_ns])
        items.order(options[:orderby])        if options[:orderby]
        items.limit(options[:limit_to_count]) if options[:limit_to_count]
        items.includes(options[:include])     if options[:include]
      else
        items = item_class.all
        items = items.where(options[:search_conditions]) if options[:search_conditions]
        items = items.order(options[:orderby])           if options[:orderby]
        items = items.limit(options[:limit_to_count])    if options[:limit_to_count]
        items = items.includes(options[:include])        if options[:include]
      end
      items
    else  # Custom find method
      items = item_class.send(options[:search_method].to_sym, name, options)
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

    rec = find_by_name(rss[:name])
    if rec
      if rec.yml_file_mtime && rec.yml_file_mtime < rss[:yml_file_mtime]
        _log.info("[#{rec.name}] file has been updated on disk, synchronizing with model")
        rec.update_attributes(rss)
      end
    else
      _log.info("[#{rss[:name]}] file has been added to disk, adding to model")
      rec = self.create!(rss)
    end

    rec.tag_add(yml[:roles], :ns => "/managed", :cat => "roles") unless yml[:roles].nil?
  end

  def self.yml_file_name(name)
    File.join(YML_DIR, name + ".yml")
  end

  def self.sync_from_yml_dir
    # Add missing feeds to model
    Dir.glob(File.join(YML_DIR, "*.yml")).each do |f|
      sync_from_yml_file(File.basename(f, ".*"))
    end

    # Remove deleted feeds from model
    RssFeed.all.each do |f|
      f.destroy unless File.exist?(RssFeed.yml_file_name(f.name))
    end
  rescue => err
    _log.log_backtrace(err)
  end

  def self.seed
    sync_from_yml_dir
  end
end
