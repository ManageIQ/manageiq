describe "migration order" do
  let(:current_release_migrations) do
    File.read(File.join(__dir__, 'data/darga_migrations')).split.map(&:to_i).sort
  end

  let(:migrations_now) do
    Dir.glob(File.join(Rails.root, "db/migrate/*.rb")).map do |f|
      File.basename(f, ".rb").split("_").first.to_i
    end.sort
  end

  let(:new_migrations) do
    migrations_now - current_release_migrations
  end

  let(:last_released_migration) do
    current_release_migrations.last
  end

  it "is correct" do
    incorrect_migration_time_stamps = []
    new_migrations.each do |m|
      incorrect_migration_time_stamps << m if m < last_released_migration
    end

    expect(incorrect_migration_time_stamps).to be_empty, <<-EOS.gsub!(/^ +/, "")
      The following migration timestamps are too early to be included in the next release:

      #{incorrect_migration_time_stamps.join("\n")}

      These migrations must be regenerated so that they will run after the latest
      released migration, #{last_released_migration}.

      This is done to prevent schema differences between migrated databases and
      newly created ones where all the migrations are run in timestamp order.
    EOS
  end
end
