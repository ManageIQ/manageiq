require_relative "test_collector"


describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  before(:each) do
    @ems = FactoryGirl.create(:ems_openshift, :name => "test_ems")
  end

  [{
     :upsert_only              => true,
     :inventory_object_refresh => true,
     :inventory_collections    => {
       :saver_strategy => :concurrent_safe_batch,
       :use_ar_object  => false,
     },
   }, {
     :upsert_only              => false,
     :inventory_object_refresh => true,
     :inventory_collections    => {
       :saver_strategy => :concurrent_safe_batch,
       :use_ar_object  => false,
     },
   }].each do |settings|
    context "with settings #{settings}" do
      before(:each) do
        stub_settings_merge(
          :ems_refresh => {:openshift => settings}
        )

        if settings[:upsert_only]
          # This is not real advanced setting. We are forcing DB to return [], which will lead to doing only upsert
          # queries. So this simulates 2 processes writing the same records.
          allow_any_instance_of(@ems.class).to receive(:container_groups).and_return(ContainerGroup.none)
        end
      end

      it "checks the full row saving versions" do
        container_group_created_on = nil

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          ContainerGroup.find_each.each do |container_group|
            expected_version = expected_version(container_group, newest_version)

            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_version}",
                :resource_version      => expected_version,
                :resource_versions_max => nil,
                :resource_versions     => {},
                :reason                => expected_version.to_s,
                :phase                 => "#{expected_version} status",
              )
            )
          end
        end

        # Expect the second+ run with same version for each record doesn't change rails versions (the row should
        # not be updated)
        container_group_current_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
        container_group_created_on         ||= container_group_current_created_on
        expect(container_group_created_on).to eq(container_group_current_created_on)
      end

      it "checks the full row saving with increasing versions" do
        bigger_newest_version = newest_version

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => bigger_newest_version,
            )
          )

          ContainerGroup.find_each.each do |container_group|
            expected_version = expected_version(container_group, bigger_newest_version)

            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_version}",
                :resource_version      => expected_version,
                :resource_versions_max => nil,
                :resource_versions     => {},
                :reason                => expected_version.to_s,
                :phase                 => "#{expected_version} status",
              )
            )
          end

          bigger_newest_version += 10
        end
      end

      it "checks the partial rows saving versions" do
        container_group_created_on = nil

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_version = expected_version(container_group, newest_version)

            expect(container_group).to(
              have_attributes(
                :name                  => nil,
                :resource_version      => nil,
                :resource_versions_max => expected_version,
                :reason                => expected_version.to_s,
                :phase                 => "#{expected_version} status",
              )
            )

            expect(version_parse(container_group.resource_versions["phase"])).to eq expected_version
            expect(version_parse(container_group.resource_versions["dns_policy"])).to eq expected_version
            expect(version_parse(container_group.resource_versions["reason"])).to eq expected_version
          end

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_current_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
          container_group_created_on         ||= container_group_current_created_on
          expect(container_group_created_on).to eq(container_group_current_created_on)
        end
      end

      it "check full then partial with the same version" do
        container_group_created_on = nil

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
        end

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_version = expected_version(container_group, newest_version)

            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_version}",
                :resource_version      => expected_version,
                :resource_versions_max => nil,
                :resource_versions     => {},
                :reason                => expected_version.to_s,
                :phase                 => "#{expected_version} status",
              )
            )
          end

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_current_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
          expect(container_group_created_on).to eq(container_group_current_created_on)
        end
      end

      it "check partial then full with the same version" do
        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_version = expected_version(container_group, newest_version)

            expect(container_group).to(
              have_attributes(
                :name                  => nil,
                :resource_version      => nil,
                :resource_versions_max => expected_version,
                :reason                => expected_version.to_s,
                :phase                 => "#{expected_version} status",
              )
            )

            expect(version_parse(container_group.resource_versions["phase"])).to eq expected_version
            expect(version_parse(container_group.resource_versions["dns_policy"])).to eq expected_version
            expect(version_parse(container_group.resource_versions["reason"])).to eq expected_version
          end
        end

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_version = expected_version(container_group, newest_version)

            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_version}",
                :resource_version      => expected_version,
                :resource_versions_max => nil,
                :resource_versions     => {},
                :reason                => expected_version.to_s,
                :phase                 => "#{expected_version} status",
              )
            )
          end
        end
      end

      it "check full then partial with the bigger version" do
        container_group_created_on = nil

        bigger_newest_version = newest_version + 1

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
        end

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => bigger_newest_version,
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_version        = expected_version(container_group, newest_version)
            expected_bigger_version = expected_version(container_group, bigger_newest_version)
            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_version}",
                :resource_version      => expected_version,
                :resource_versions_max => expected_bigger_version,
                :reason                => expected_bigger_version.to_s,
                :phase                 => "#{expected_bigger_version} status",
              )
            )

            expect(version_parse(container_group.resource_versions["phase"])).to eq expected_bigger_version
            expect(version_parse(container_group.resource_versions["dns_policy"])).to eq expected_bigger_version
            expect(version_parse(container_group.resource_versions["reason"])).to eq expected_bigger_version
          end

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_current_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
          expect(container_group_created_on).to eq(container_group_current_created_on)
        end
      end

      it "check partial then full with the bigger version" do
        bigger_newest_version = newest_version + 1

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )
        end

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => bigger_newest_version,
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_bigger_version = expected_version(container_group, bigger_newest_version)

            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_bigger_version}",
                :resource_version      => expected_bigger_version,
                :resource_versions_max => nil,
                :resource_versions     => {},
                :reason                => expected_bigger_version.to_s,
                :phase                 => "#{expected_bigger_version} status",
              )
            )
          end
        end
      end

      it "checks that full refresh with lower version running after partial, will turn to partial updates" do
        bigger_newest_version      = newest_version + 1
        even_bigger_newest_version = newest_version + 2

        2.times do
          TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => bigger_newest_version,
            )
          )
        end

        2.times do
          persister = TestCollector.generate_batches_of_full_container_group_data(
            :ems_name         => @ems.name,
            :resource_version => newest_version,
            :index_start      => 0,
            :batch_size       => 2
          )

          TestCollector.generate_batches_of_full_container_group_data(
            :ems_name         => @ems.name,
            :resource_version => even_bigger_newest_version,
            :persister        => persister,
            :index_start      => 1,
            :batch_size       => 2
          )

          TestCollector.refresh(persister)

          ContainerGroup.find_each do |container_group|
            expected_version             = expected_version(container_group, newest_version)
            expected_bigger_version      = expected_version(container_group, bigger_newest_version)
            expected_even_bigger_version = expected_version(container_group, even_bigger_newest_version)

            if index(container_group) >= 2
              # This gets full row update
              expect(container_group).to(
                have_attributes(
                  :name => "container_group_#{expected_even_bigger_version}",
                  # TODO(lsmola) so this means we do full by partial, so it should be 'expected_version', how to do it?
                  # It should also flip complete => true
                  :resource_version      => expected_even_bigger_version,
                  :resource_versions_max => nil,
                  :resource_versions     => {},
                  :reason                => expected_even_bigger_version.to_s,
                  :phase                 => "#{expected_even_bigger_version} status",
                )
              )
            else
              # This gets full row, transformed to skeletal update, leading to only updating :name
              expect(container_group).to(
                have_attributes(
                  :name => "container_group_#{expected_version}",
                  # TODO(lsmola) so this means we do full by partial, so it should be 'expected_version', how to do it?
                  # It should also flip complete => true
                  :resource_version      => nil,
                  :resource_versions_max => expected_bigger_version,
                  :reason                => expected_bigger_version.to_s,
                  :phase                 => "#{expected_bigger_version} status",
                )
              )

              expect(version_parse(container_group.resource_versions["phase"])).to eq expected_bigger_version
              expect(version_parse(container_group.resource_versions["dns_policy"])).to eq expected_bigger_version
              expect(version_parse(container_group.resource_versions["reason"])).to eq expected_bigger_version
            end
          end
        end
      end

      it "checks that 2 different partial records are batched and saved correctly when starting with older" do
        bigger_newest_version = newest_version + 1

        2.times do
          persister = TestCollector.generate_batches_of_partial_container_group_data(
            :ems_name         => @ems.name,
            :resource_version => newest_version,
          )

          TestCollector.generate_batches_of_different_partial_container_group_data(
            :ems_name         => @ems.name,
            :resource_version => bigger_newest_version,
            :persister        => persister,
            :index_start      => 1,
            :batch_size       => 2
          )

          TestCollector.refresh(persister)

          TestCollector.refresh(
            TestCollector.generate_batches_of_different_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => bigger_newest_version,
              :index_start      => 0,
              :batch_size       => 2
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_version        = expected_version(container_group, newest_version)
            expected_bigger_version = expected_version(container_group, bigger_newest_version)
            expect(container_group).to(
              have_attributes(
                :name                  => nil,
                :resource_version      => nil,
                :message               => expected_bigger_version.to_s,
                :resource_versions_max => expected_bigger_version,
                :reason                => expected_bigger_version.to_s,
                :phase                 => "#{expected_version} status",
              )
            )

            expect(version_parse(container_group.resource_versions["phase"])).to eq expected_version
            expect(version_parse(container_group.resource_versions["dns_policy"])).to eq expected_bigger_version
            expect(version_parse(container_group.resource_versions["reason"])).to eq expected_bigger_version
          end
        end
      end

      it "checks that 2 different partial records are batched and saved correctly when starting with newer" do
        bigger_newest_version = newest_version + 1

        persister = TestCollector.generate_batches_of_partial_container_group_data(
          :ems_name         => @ems.name,
          :resource_version => bigger_newest_version,
        )

        TestCollector.generate_batches_of_different_partial_container_group_data(
          :ems_name         => @ems.name,
          :resource_version => newest_version,
          :persister        => persister,
          :index_start      => 1,
          :batch_size       => 2
        )

        TestCollector.refresh(persister)

        ContainerGroup.find_each do |container_group|
          expected_version        = expected_version(container_group, newest_version)
          expected_bigger_version = expected_version(container_group, bigger_newest_version)
          expect(container_group).to(
            have_attributes(
              :name                  => nil,
              :resource_version      => nil,
              :resource_versions_max => expected_bigger_version,
              :reason                => expected_bigger_version.to_s,
              :phase                 => "#{expected_bigger_version} status",
            )
          )

          if index(container_group) >= 2
            # version is only set for container_groups >= 2
            expect(container_group).to(
              have_attributes(
                :message => expected_version.to_s,
              )
            )
            expect(version_parse(container_group.resource_versions["message"])).to eq expected_version
          else
            expect(container_group).to(
              have_attributes(
                :message => nil,
              )
            )
            expect(container_group.resource_versions["message"]).to eq nil
          end
          expect(version_parse(container_group.resource_versions["phase"])).to eq expected_bigger_version
          expect(version_parse(container_group.resource_versions["dns_policy"])).to eq expected_bigger_version
          expect(version_parse(container_group.resource_versions["reason"])).to eq expected_bigger_version
        end

        TestCollector.refresh(
          TestCollector.generate_batches_of_different_partial_container_group_data(
            :ems_name         => @ems.name,
            :resource_version => newest_version,
            :index_start      => 0,
            :batch_size       => 2
          )
        )

        ContainerGroup.find_each do |container_group|
          expected_version        = expected_version(container_group, newest_version)
          expected_bigger_version = expected_version(container_group, bigger_newest_version)
          expect(container_group).to(
            have_attributes(
              :name                  => nil,
              :resource_version      => nil,
              :resource_versions_max => expected_bigger_version,
              :reason                => expected_bigger_version.to_s,
              :phase                 => "#{expected_bigger_version} status",
              :message               => expected_version.to_s,
            )
          )

          # TODO(lsmola) wrong, this should be expected_version, we need to set the right versions on parsing time
          expect(version_parse(container_group.resource_versions["phase"])).to eq expected_bigger_version
          expect(version_parse(container_group.resource_versions["dns_policy"])).to eq expected_bigger_version
          expect(version_parse(container_group.resource_versions["reason"])).to eq expected_bigger_version
          expect(version_parse(container_group.resource_versions["message"])).to eq expected_version
        end
      end

      it "checks that 2 different full rows are saved corerctly when starting with newer" do
        bigger_newest_version = newest_version + 1

        2.times do
          persister = TestCollector.generate_batches_of_full_container_group_data(
            :ems_name         => @ems.name,
            :resource_version => bigger_newest_version,
          )

          TestCollector.generate_batches_of_full_container_group_data(
            :ems_name         => @ems.name,
            :resource_version => newest_version,
            :persister        => persister,
            :index_start      => 1,
            :batch_size       => 2
          )

          TestCollector.refresh(persister)

          ContainerGroup.find_each do |container_group|
            expected_bigger_version = expected_version(container_group, bigger_newest_version)
            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_bigger_version}",
                :resource_version      => expected_bigger_version,
                :resource_versions     => {},
                :resource_versions_max => nil,
                :message               => expected_bigger_version.to_s,
                :reason                => expected_bigger_version.to_s,
                :phase                 => "#{expected_bigger_version} status",
              )
            )
          end

          TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
              :index_start      => 0,
              :batch_size       => 2
            )
          )

          ContainerGroup.find_each do |container_group|
            expected_bigger_version = expected_version(container_group, bigger_newest_version)
            expect(container_group).to(
              have_attributes(
                :name                  => "container_group_#{expected_bigger_version}",
                :resource_version      => expected_bigger_version,
                :resource_versions     => {},
                :resource_versions_max => nil,
                :message               => expected_bigger_version.to_s,
                :reason                => expected_bigger_version.to_s,
                :phase                 => "#{expected_bigger_version} status",
              )
            )
          end
        end
      end
    end
  end

  private

  def index(container_group)
    container_group.dns_policy.to_i
  end

  def expected_version(container_group, newest_version)
    newest_version + index(container_group) * 100
  end

  def newest_version
    42
  end

  def version_parse(version)
    version.to_i
  end
end
