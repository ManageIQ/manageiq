require "spec_helper"

describe RssFeed::ImportExport do
  before do
    MiqRegion.seed
    @user = FactoryGirl.create(:user_admin)
  end

  context ".import_from_hash" do
    before do
      @feed_to_be_imported = {"RssFeed" => {"name"           => "test_rss_feed",
                                            "title"          => "My test RSS feed",
                                            "link"           => "/alert/rss?feed=test_rss_feed",
                                            "description"    => "Test Rss Feed",
                                            "yml_file_mtime" => nil
                                           }
      }
      @options             = {
        :overwrite => true,
        :userid    => @user.userid
      }
    end

    subject { RssFeed.import_from_hash(@feed_to_be_imported, @options).last }

    context "new" do
      it "preview" do
        expect(subject[:status]).to eq(:add)
        RssFeed.count.should == 0
      end

      it "import" do
        @options[:save] = true
        expect(subject[:status]).to eq(:add)
        RssFeed.count.should == 1
      end
    end

    context "existing" do
      before do
        @title = "Latest news"
        @feed_org = FactoryGirl.create(:rss_feed,
                                       :name  => "test_rss_feed",
                                       :title => @title,
                                       :link  => "/alert/rss?feed=test_rss_feed"
                                      )
      end

      context "overwrite" do
        it "preview" do
          expect(subject[:status]).to eq(:update)
          RssFeed.first.title.should == @title
        end

        it "import" do
          @options[:save] = true
          expect(subject[:status]).to eq(:update)
          RssFeed.first.title.should == "My test RSS feed"
        end
      end

      context "no overwrite" do
        before { @options[:overwrite] = false }

        it "preview" do
          expect(subject[:status]).to eq(:keep)
          RssFeed.first.title.should == @title
        end

        it "import" do
          @options[:save] = true
          expect(subject[:status]).to eq(:keep)
          RssFeed.first.title.should == @title
        end
      end
    end
  end
end
