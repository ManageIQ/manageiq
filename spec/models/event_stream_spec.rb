describe EventStream do
  describe ".event_groups" do
    EventStream.event_groups.each do |group_name, group_data|
      EventStream::GROUP_LEVELS.each do |level|
        group_data[level]&.each do |typ|
          it ":#{group_name}/:#{level}/#{typ} is string or regex", :providers_common => true do
            expect(typ.kind_of?(Regexp) || typ.kind_of?(String)).to eq(true)
          end

          if typ.kind_of?(Regexp)
            it ":#{group_name}/:#{level}/#{typ} is usable in SQL queries", :providers_common => true do
              expect { EventStream.where("event_type ~ ?", typ.source).to_a }
                .to_not raise_error
            end

            it ":#{group_name}/:#{level}/#{typ} only uses case insensitivity option", :providers_common => true do
              expect(typ.options & (Regexp::EXTENDED | Regexp::MULTILINE)).to eq(0)
            end
          end
        end
      end
    end
  end
end
