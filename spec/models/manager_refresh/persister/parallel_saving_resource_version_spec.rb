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

      it "checks the full row saving with the same versions" do
        container_group_created_on = nil

        2.times do |i|
          persister = TestCollector.refresh(
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

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
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

        2.times do |i|
          persister = TestCollector.refresh(
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

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister, :container_groups => ContainerGroup.all)
            match_deleted(persister)
          end

          bigger_newest_version += 10
        end
      end

      it "checks the partial rows saving with the same versions" do
        container_group_created_on = nil

        2.times do |i|
          persister = TestCollector.refresh(
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
            expect(container_group.resource_versions).to(
              match(
                "phase"      => expected_version,
                "dns_policy" => expected_version,
                "reason"     => expected_version,
              )
            )
          end

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_current_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
          container_group_created_on         ||= container_group_current_created_on
          expect(container_group_created_on).to eq(container_group_current_created_on)

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end
      end

      it "check full then partial with the same version" do
        container_group_created_on = nil

        2.times do |i|
          persister = TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end

        2.times do
          persister = TestCollector.refresh(
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

          match_created(persister)
          match_updated(persister)
          match_deleted(persister)
        end
      end

      it "check partial then full with the same version" do
        2.times do |i|
          persister = TestCollector.refresh(
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

            expect(container_group.resource_versions).to(
              match(
                "phase"      => expected_version,
                "dns_policy" => expected_version,
                "reason"     => expected_version,
              )
            )
          end

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end

        2.times do |i|
          persister = TestCollector.refresh(
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

          if i == 0
            match_created(persister)
            match_updated(persister, :container_groups => ContainerGroup.all)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end
      end

      it "check full then partial with the bigger version" do
        container_group_created_on = nil

        bigger_newest_version = newest_version + 1

        2.times do |i|
          persister = TestCollector.refresh(
            TestCollector.generate_batches_of_full_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end

        2.times do |i|
          persister = TestCollector.refresh(
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

            expect(container_group.resource_versions).to(
              match(
                "phase"      => expected_bigger_version,
                "dns_policy" => expected_bigger_version,
                "reason"     => expected_bigger_version,
              )
            )
          end

          # Expect the second+ run with same version for each record doesn't change rails versions (the row should
          # not be updated)
          container_group_current_created_on = ContainerGroup.where(:dns_policy => "1").first.created_on
          expect(container_group_created_on).to eq(container_group_current_created_on)

          if i == 0
            match_created(persister)
            match_updated(persister, :container_groups => ContainerGroup.all)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end
      end

      it "check partial then full with the bigger version" do
        bigger_newest_version = newest_version + 1

        2.times do |i|
          persister = TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => newest_version,
            )
          )

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end

        2.times do |i|
          persister = TestCollector.refresh(
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

          if i == 0
            match_created(persister)
            match_updated(persister, :container_groups => ContainerGroup.all)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end
      end

      it "checks that full refresh with lower version running after partial, will turn to partial updates" do
        bigger_newest_version      = newest_version + 1
        even_bigger_newest_version = newest_version + 2

        2.times do |i|
          persister = TestCollector.refresh(
            TestCollector.generate_batches_of_partial_container_group_data(
              :ems_name         => @ems.name,
              :resource_version => bigger_newest_version,
            )
          )

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end

        2.times do |i|
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

          persister = TestCollector.refresh(persister)

          ContainerGroup.find_each do |container_group|
            expected_version             = expected_version(container_group, newest_version)
            expected_bigger_version      = expected_version(container_group, bigger_newest_version)
            expected_even_bigger_version = expected_version(container_group, even_bigger_newest_version)

            if index(container_group) >= 2
              # This gets full row update
              expect(container_group).to(
                have_attributes(
                  :name                  => "container_group_#{expected_even_bigger_version}",
                  :message               => "#{expected_even_bigger_version}",
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
                  :name                  => "container_group_#{expected_version}",
                  :message               => "#{expected_version}",
                  :resource_version      => nil,
                  :resource_versions_max => expected_bigger_version,
                  :reason                => expected_bigger_version.to_s,
                  :phase                 => "#{expected_bigger_version} status",
                )
              )

              expect(container_group.resource_versions).to(
                match(
                  "dns_policy" => expected_bigger_version,
                  "message"    => expected_version,
                  "name"       => expected_version,
                  "phase"      => expected_bigger_version,
                  "reason"     => expected_bigger_version,
                )
              )
            end
          end

          if i == 0
            match_created(persister)
            match_updated(persister, :container_groups => ContainerGroup.all)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end
        end
      end

      it "checks that 2 different partial records are batched and saved correctly when starting with older" do
        bigger_newest_version = newest_version + 1

        2.times do |i|
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

          persister = TestCollector.refresh(persister)

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end

          persister = TestCollector.refresh(
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

            expect(container_group.resource_versions).to(
              match(
                "dns_policy" => expected_bigger_version,
                "message"    => expected_bigger_version,
                "phase"      => expected_version,
                "reason"     => expected_bigger_version,
              )
            )
          end

          if i == 0
            match_created(persister)
            match_updated(persister, :container_groups => ContainerGroup.where(:dns_policy => ["0", "1"]))
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
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

        persister = TestCollector.refresh(persister)

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
            expect(container_group.resource_versions).to(
              match(
                "dns_policy" => expected_bigger_version,
                "message"    => expected_version,
                "phase"      => expected_bigger_version,
                "reason"     => expected_bigger_version,
              )
            )
          else
            expect(container_group).to(
              have_attributes(
                :message => nil,
              )
            )
            expect(container_group.resource_versions).to(
              match(
                "dns_policy" => expected_bigger_version,
                "phase"      => expected_bigger_version,
                "reason"     => expected_bigger_version,
              )
            )
          end
        end

        match_created(persister, :container_groups => ContainerGroup.all)
        match_updated(persister)
        match_deleted(persister)

        persister = TestCollector.refresh(
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

          expect(container_group.resource_versions).to(
            match(
              "dns_policy" => expected_bigger_version,
              "message"    => expected_version,
              "phase"      => expected_bigger_version,
              "reason"     => expected_bigger_version,
            )
          )
        end

        match_created(persister)
        match_updated(persister, :container_groups => ContainerGroup.where(:dns_policy => ["0", "1"]))
        match_deleted(persister)
      end

      it "checks that 2 different full rows are saved correctly when starting with newer" do
        bigger_newest_version = newest_version + 1

        2.times do |i|
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

          persister = TestCollector.refresh(persister)

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

          if i == 0
            match_created(persister, :container_groups => ContainerGroup.all)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          end

          persister = TestCollector.refresh(
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

          if i == 0
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
          else
            match_created(persister)
            match_updated(persister)
            match_deleted(persister)
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

  def records_identities(arels)
    arels.transform_values! do |value|
      value.to_a.map { |x| {:id => x.id} }.sort_by { |x| x[:id] }
    end
  end

  def match_created(persister, records = {})
    match_records(persister, :created_records, records)
  end

  def match_updated(persister, records = {})
    match_records(persister, :updated_records, records)
  end

  def match_deleted(persister, records = {})
    match_records(persister, :deleted_records, records)
  end

  def persister_records_identities(persister, kind)
    persister.collections.map { |key, value| [key, value.send(kind)] if value.send(kind).present? }.compact.to_h.transform_values! do |value|
      value.sort_by { |x| x[:id] }
    end
  end

  def match_records(persister, kind, records)
    expect(
      persister_records_identities(persister, kind)
    ).to(
      match(records_identities(records))
    )
  end
end
