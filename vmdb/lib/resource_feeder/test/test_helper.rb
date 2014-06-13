RAILS_ENV = 'test'
require File.expand_path(File.join(File.dirname(__FILE__), '../../../../config/environment.rb'))
require 'action_controller/test_process'
require 'breakpoint'
require 'ostruct'

class Post
  attr_reader :id, :created_at
  def save; @id = 1; @created_at = Time.now.utc end
  def new_record?; @id.nil? end

  [:title, :name].each do |attr_name|
    define_method attr_name do
      "feed title (#{attr_name})"
    end
  end

  [:description, :body].each do |attr_name|
    define_method attr_name do
      "<p>feed description (#{attr_name})</p>"
    end
  end

  def full_html_body
    "<strong>Here is some <i>full</i> content, with out any excerpts</strong>"
  end

  def create_date
    @created_at - 5.minutes
  end
end

class Test::Unit::TestCase
  include ResourceFeeder::Rss, ResourceFeeder::Atom

  def render_feed(xml)
    @response = OpenStruct.new
    @response.headers = {'Content-Type' => 'text/xml'}
    @response.body = xml
  end

  def rss_feed_for_with_ostruct(resources, options = {})
    render_feed rss_feed_for_without_ostruct(resources, options)
  end

  def atom_feed_for_with_ostruct(resources, options = {})
    render_feed atom_feed_for_without_ostruct(resources, options)
  end

  alias_method_chain :rss_feed_for,  :ostruct
  alias_method_chain :atom_feed_for, :ostruct

  def html_document
    @html_document ||= HTML::Document.new(@response.body, false, true)
  end

  def posts_url
    "http://example.com/posts"
  end

  def post_url(post)
    "http://example.com/posts/#{post.id}"
  end
end
