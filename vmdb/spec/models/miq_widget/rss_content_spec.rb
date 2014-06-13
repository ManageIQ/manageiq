# encoding: UTF-8
require "spec_helper"

describe "Widget RSS Content" do

  CNN_XML = <<-EOF
  <?xml version="1.0" encoding="ISO-8859-1"?>
  <?xml-stylesheet type="text/xsl" media="screen" href="/~d/styles/rss2full.xsl"?><?xml-stylesheet type="text/css" media="screen" href="http://rss.cnn.com/~d/styles/itemcontent.css"?><rss xmlns:media="http://search.yahoo.com/mrss/" xmlns:feedburner="http://rssnamespace.org/feedburner/ext/1.0" version="2.0"><channel>
  <title>CNN.com</title>
  <link>http://www.cnn.com/?eref=rss_topstories</link>
  <description>CNN.com delivers up-to-the-minute news and information on the latest top stories, weather, entertainment, politics and more.</description>
  <language>en-us</language>
  <copyright>� 2011 Cable News Network LP, LLLP.</copyright>
  <pubDate>Wed, 27 Jul 2011 14:14:29 EDT</pubDate>
  <ttl>5</ttl>
  <image>
  <title>CNN.com</title>
  <link>http://www.cnn.com/?eref=rss_topstories</link>
  <url>http://i2.cdn.turner.com/cnn/.element/img/1.0/logo/cnn.logo.rss.gif</url>
  <width>144</width>
  <height>33</height>
  <description>CNN.com delivers up-to-the-minute news and information on the latest top stories, weather, entertainment, politics and more.</description>
  </image>
  <atom10:link xmlns:atom10="http://www.w3.org/2005/Atom" rel="self" type="application/rss+xml" href="http://rss.cnn.com/rss/cnn_topstories" /><feedburner:info uri="rss/cnn_topstories" /><atom10:link xmlns:atom10="http://www.w3.org/2005/Atom" rel="hub" href="http://pubsubhubbub.appspot.com/" /><thespringbox:skin xmlns:thespringbox="http://www.thespringbox.com/dtds/thespringbox-1.0.dtd">http://rss.cnn.com/rss/cnn_topstories?format=skin</thespringbox:skin><item>
  <title>The reality of the debt drama</title>
  <guid isPermaLink="false">http://www.cnn.com/money/2011/07/27/news/economy/debt_ceiling_fight/index.htm?eref=rss_topstories</guid>
  <link>http://rss.cnn.com/~r/rss/cnn_topstories/~3/IVSda4bkcfs/index.htm</link>
  <description>With all the Washington dysfunction over the debt ceiling...</description>
  <pubDate>Wed, 27 Jul 2011 13:06:08 EDT</pubDate>
  <feedburner:origLink>http://www.cnn.com/money/2011/07/27/news/economy/debt_ceiling_fight/index.htm?eref=rss_topstories</feedburner:origLink></item>
  <item>
  <title>Norway hunts answers after massacre</title>
  <guid isPermaLink="false">http://www.cnn.com/2011/WORLD/europe/07/27/norway.terror.attacks/index.html?eref=rss_topstories</guid>
  <link>http://rss.cnn.com/~r/rss/cnn_topstories/~3/XoIebNgCEok/index.html</link>
  <description>Norway's Prime Minister Jens Stoltenberg invited foreign journalists...</description>
  <pubDate>Wed, 27 Jul 2011 13:40:58 EDT</pubDate>
  <feedburner:origLink>http://www.cnn.com/2011/WORLD/europe/07/27/norway.terror.attacks/index.html?eref=rss_topstories</feedburner:origLink></item>
  <item>
  <title>Shooter's legacy</title>
  <guid isPermaLink="false">http://www.cnn.com/2011/WORLD/europe/07/27/norway.shooter/index.html?eref=rss_topstories</guid>
  <link>http://rss.cnn.com/~r/rss/cnn_topstories/~3/aYMEkUdhdQQ/index.html</link>
  <description>Norwegian shooter Anders Behring Breivik may have left an additional murderous...</description>
  <pubDate>Wed, 27 Jul 2011 14:11:48 EDT</pubDate>
  <feedburner:origLink>http://www.cnn.com/2011/WORLD/europe/07/27/norway.shooter/index.html?eref=rss_topstories</feedburner:origLink></item>
  <item>
  <title>U.S. Olympic skier kills himself</title>
  <guid isPermaLink="false">http://www.cnn.com/2011/SPORT/07/27/utah.skier.peterson/index.html?eref=rss_topstories</guid>
  <link>http://rss.cnn.com/~r/rss/cnn_topstories/~3/pb0ba0aYlIs/index.html</link>
  <description>Freestyle skier Jeret "Speedy" Peterson, who won a silver...</description>
  <pubDate>Wed, 27 Jul 2011 09:59:51 EDT</pubDate>
  <feedburner:origLink>http://www.cnn.com/2011/SPORT/07/27/utah.skier.peterson/index.html?eref=rss_topstories</feedburner:origLink></item>
  <item>
  <title>Gulf storm could become cyclone</title>
  <guid isPermaLink="false">http://www.cnn.com/2011/WORLD/americas/07/27/mexico.tropical.weather/index.html?eref=rss_topstories</guid>
  <link>http://rss.cnn.com/~r/rss/cnn_topstories/~3/V-PFG1wwtgU/index.html</link>
  <description>Oil companies with off-shore platforms in the Gulf of Mexico are...</description>
  <pubDate>Wed, 27 Jul 2011 13:27:50 EDT</pubDate>
  <feedburner:origLink>http://www.cnn.com/2011/WORLD/americas/07/27/mexico.tropical.weather/index.html?eref=rss_topstories</feedburner:origLink></item>
  </channel></rss>
  EOF

  before(:each) do
    MiqRegion.seed
    RssFeed.sync_from_yml_dir

    guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid => guid)
    FactoryGirl.create(:miq_server, :zone => FactoryGirl.create(:zone), :guid => guid, :status => "started")
    MiqServer.my_server(true)

    @admin       = FactoryGirl.create(:user_admin)
    @admin_group = @admin.current_group

    10.times do |i|
      FactoryGirl.create(:vm_vmware, :name => "VmVmware #{i}")
    end

    MiqWidget.sync_from_hash(YAML.load('
      description: rss_cnn
      title: CNN Top Stories
      content_type: rss
      options:
        :url: http://rss.cnn.com/rss/cnn_topstories.rss
        :row_count: 5
      visibility: _ALL_
      enabled: true
      read_only: true
    '))

    MiqWidget.sync_from_hash(YAML.load('
      description: rss_newest_vms
      title: "EVM: Recently Discovered VMs"
      content_type: rss
      options:
        :row_count: 5
      visibility:
        :roles:
        - _ALL_
      resource_name: newest_vms
      resource_type: RssFeed
      enabled: true
      read_only: true
    '))
  end


  it "#generate_content external rss for user" do
    widget = MiqWidget.find_by_description("rss_cnn")

    Net::HTTP.stub(:get).and_return(CNN_XML)
    content = widget.generate_one_content_for_user(@admin_group, @admin)
    content.should be_kind_of MiqWidgetContent
    content.contents.scan("</tr>").length.should == widget.options[:row_count]
    content.contents.scan("<a href").length.should == widget.options[:row_count]
    widget.contents_for_user(@admin).should == content
    Net::HTTP.unstub(:get)
  end

  it "#generate_content internal rss for user" do
    widget = MiqWidget.find_by_description("rss_newest_vms")

    content = widget.generate_one_content_for_user(@admin_group, @admin)
    content.should be_kind_of MiqWidgetContent
    content.contents.scan("</tr>").length.should == widget.options[:row_count]
    content.contents.scan("VmVmware").length.should == widget.options[:row_count]
    widget.contents_for_user(@admin).should == content
  end

  it "#generate_content external rss for group" do
    widget = MiqWidget.find_by_description("rss_cnn")

    Net::HTTP.stub(:get).and_return(CNN_XML)
    content = widget.generate_one_content_for_group(@admin.current_group, @admin.get_timezone)
    content.should be_kind_of MiqWidgetContent
    content.contents.scan("</tr>").length.should == widget.options[:row_count]
    content.contents.scan("<a href").length.should == widget.options[:row_count]
    widget.contents_for_user(@admin).should == content
    Net::HTTP.unstub(:get)
  end

  it "#generate_content internal rss for group" do
    widget = MiqWidget.find_by_description("rss_newest_vms")

    content = widget.generate_one_content_for_group(@admin.current_group, @admin.get_timezone)
    content.should be_kind_of MiqWidgetContent
    content.contents.scan("</tr>").length.should == widget.options[:row_count]
    content.contents.scan("VmVmware").length.should == widget.options[:row_count]
    widget.contents_for_user(@admin).should == content
  end

end
