require File.dirname(__FILE__) + '/test_helper'
class RssFeedTest < Test::Unit::TestCase
  def setup
    @records = Array.new(5).fill(Post.new)
    @records.each &:save
  end

  def test_default_rss_feed
    rss_feed_for @records

    assert_select 'rss[version="2.0"]' do
      assert_select 'channel' do
        assert_select '>title', 'Posts'
        assert_select '>link',  'http://example.com/posts'
        assert_select 'language', 'en-us'
        assert_select 'ttl', '40'
      end
      assert_select 'item', 5 do
        assert_select 'title', :text => 'feed title (title)'
        assert_select 'description', '&lt;p&gt;feed description (description)&lt;/p&gt;'
        %w(guid link).each do |node|
          assert_select node, 'http://example.com/posts/1'
        end
        assert_select 'pubDate', @records.first.created_at.to_s(:rfc822)
      end
    end
  end

  def test_should_allow_custom_feed_options
    rss_feed_for @records, :feed => { :title => 'Custom Posts', :link => '/posts', :description => 'stuff', :language => 'en-gb', :ttl => '80' }

    assert_select 'channel>title', 'Custom Posts'
    assert_select 'channel>link',  '/posts'
    assert_select 'channel>description', 'stuff'
    assert_select 'channel>language', 'en-gb'
    assert_select 'channel>ttl', '80'
  end

  def test_should_allow_custom_item_attributes
    rss_feed_for @records, :item => { :title => :name, :description => :body, :pub_date => :create_date, :link => :id }

    assert_select 'item', 5 do
      assert_select 'title', :text => 'feed title (name)'
      assert_select 'description', '&lt;p&gt;feed description (body)&lt;/p&gt;'
      assert_select 'pubDate', (@records.first.created_at - 5.minutes).to_s(:rfc822)
      assert_select 'link', '1'
      assert_select 'guid', '1'
    end
  end

  def test_should_allow_custom_item_attribute_blocks
    rss_feed_for @records, :item => { :title => lambda { |r| r.name }, :description => lambda { |r| r.body }, :pub_date => lambda { |r| r.create_date },
      :link => lambda { |r| "/#{r.created_at.to_i}" }, :guid => lambda { |r| r.created_at.to_i } }

    assert_select 'item', 5 do
      assert_select 'title', :text => 'feed title (name)'
      assert_select 'description', '&lt;p&gt;feed description (body)&lt;/p&gt;'
      assert_select 'pubDate', (@records.first.created_at - 5.minutes).to_s(:rfc822)
    end
  end

  # note that assert_select isnt easily able to get elements that have xml namespaces (as it thinks they are
  # invalid html psuedo children), so we do some manual testing with the response body
  def test_should_allow_content_encoded_for_items
    rss_feed_for @records, :item => { :content_encoded => :full_html_body }

    html_content = "<strong>Here is some <i>full</i> content, with out any excerpts</strong>"
    assert_equal 5, @response.body.scan("<![CDATA[#{html_content}]]>").size
    assert_select 'item', 5 do
      assert_select 'description + *', "<![CDATA[#{html_content}" # assert_select seems to strip the ending cdata tag
    end
  end

  def test_should_have_content_encoded_namespace_if_used
    rss_feed_for @records, :item => { :content_encoded => :full_html_body }
    assert_equal %[<rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">\n],
        @response.body.grep(/<rss version="2\.0.*"/).first
  end

  def test_should_have_normal_rss_root_without_content_encoded
    rss_feed_for @records
    assert_equal %[<rss version="2.0">\n],
        @response.body.grep(/<rss version="2\.0.*"/).first
  end

end
