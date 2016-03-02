describe ApplicationController, "#Timezone" do
  before do
    _, @server, = EvmSpecHelper.create_guid_miq_server_zone
  end

  context "#get_timezone_offset" do
    context "for a server" do
      it "with a system default" do
        stub_settings(:server => {:timezone => "Eastern Time (US & Canada)"})

        Timecop.freeze(Time.utc(2013, 1, 1)) do
          expect(subject.get_timezone_offset).to eq(-5.hours)
        end
      end

      it "without a system default" do
        stub_settings({})
        expect(subject.get_timezone_offset).to eq(0.hours)
      end
    end

    context "for a user" do
      it "who doesn't exist" do
        expect(subject.get_timezone_offset(nil)).to eq(0.hours)
      end

      it "with a timezone" do
        user = FactoryGirl.create(:user, :settings => {:display => {:timezone => "Pacific Time (US & Canada)"}})
        Timecop.freeze(Time.utc(2013, 1, 1)) do
          expect(subject.get_timezone_offset(user)).to eq(-8.hours)
        end
      end

      context "without a timezone" do
        it "with a system default" do
          user = FactoryGirl.create(:user)
          stub_settings(:server => {:timezone => "Eastern Time (US & Canada)"})

          Timecop.freeze(Time.utc(2013, 1, 1)) do
            expect(subject.get_timezone_offset(user)).to eq(-5.hours)
          end
        end

        it "with a system default and nil user" do
          stub_settings(:server => {:timezone => "Eastern Time (US & Canada)"})
          Timecop.freeze(Time.utc(2013, 1, 1)) do
            expect(subject.get_timezone_offset(nil)).to eq(-5.hours)
          end
        end

        it "without a system default" do
          user = FactoryGirl.create(:user)
          stub_settings({})

          expect(subject.get_timezone_offset(user)).to eq(0.hours)
        end
      end
    end
  end
end
