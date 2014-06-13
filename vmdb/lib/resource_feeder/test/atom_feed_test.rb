require File.dirname(__FILE__) + '/test_helper'
class AtomFeedTest < Test::Unit::TestCase
  attr_reader :request

  def setup
    @request = OpenStruct.new
    @request.host_with_port = 'example.com'
    @records = Array.new(5).fill(Post.new)
    @records.each &:save
  end

  def test_default_atom_feed
    atom_feed_for @records

    assert_select 'feed' do
      assert_select '>title', 'Posts'
      assert_select '>id', "tag:#{request.host_with_port}:Posts"
      assert_select '>link' do
        assert_select "[rel='alternate']"
        assert_select "[type='text/html']"
        assert_select "[href='http://example.com/posts']"
      end
      assert_select 'entry', 5 do
        assert_select 'title', :text => 'feed title (title)'
        assert_select "content[type='html']", '&lt;p&gt;feed description (description)&lt;/p&gt;'
        assert_select 'id', "tag:#{request.host_with_port},#{@records.first.created_at.xmlschema}:#{'http://example.com/posts/1'}"
        assert_select 'published', @records.first.created_at.xmlschema
        assert_select 'updated', @records.first.created_at.xmlschema
        assert_select 'link' do
          assert_select "[rel='alternate']"
          assert_select "[type='text/html']"
          assert_select "[href='http://example.com/posts/1']"
        end
      end
    end
  end

  def test_should_allow_custom_feed_options
    atom_feed_for @records, :feed => { :title => 'Custom Posts', :link => '/posts', :description => 'stuff', :self => '/posts.atom' }

    assert_select 'feed>title', 'Custom Posts'
    assert_select "feed>link[href='/posts']"
    assert_select 'feed>subtitle', 'stuff'
    assert_select 'feed>link' do
      assert_select "[rel='self']"
      assert_select "[type='application/atom+xml']"
      assert_select "[href='/posts.atom']"
    end
  end

  def test_should_allow_custom_item_attributes
    atom_feed_for @records, :item => { :title => :name, :description => :body, :pub_date => :create_date, :link => :id }

    assert_select 'entry', 5 do
      assert_select 'title', :text => 'feed title (name)'
      assert_select "content[type='html']", '&lt;p&gt;feed description (body)&lt;/p&gt;'
      assert_select 'published', (@records.first.created_at - 5.minutes).xmlschema
      assert_select 'updated', (@records.first.created_at - 5.minutes).xmlschema
      assert_select 'id', "tag:#{request.host_with_port},#{(@records.first.created_at - 5.minutes).xmlschema}:1"
      assert_select 'link' do
        assert_select "[rel='alternate']"
        assert_select "[type='text/html']"
        assert_select "[href='1']"
      end
    end
  end

  def test_should_allow_custom_item_attribute_blocks
    atom_feed_for @records, :item => { :title => lambda { |r| r.name }, :description => lambda { |r| r.body }, :pub_date => lambda { |r| r.create_date },
      :link => lambda { |r| "/#{r.created_at.to_i}" }, :guid => lambda { |r| r.created_at.to_i } }

    assert_select 'entry', 5 do
      assert_select 'title', :text => 'feed title (name)'
      assert_select "content[type='html']", '&lt;p&gt;feed description (body)&lt;/p&gt;'
      assert_select 'published', (@records.first.created_at - 5.minutes).xmlschema
      assert_select 'updated', (@records.first.created_at - 5.minutes).xmlschema
      assert_select 'id', /:\d+$/
      assert_select 'link' do
        assert_select "[rel='alternate']"
        assert_select "[type='text/html']"
        assert_select "[href=?]", /^\/\d+$/
      end
    end
  end
end
