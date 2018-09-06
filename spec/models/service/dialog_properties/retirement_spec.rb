describe Service::DialogProperties::Retirement do
  let(:time) { Time.new(2018, 7, 21, 12, 20, 0, 0) }

  it 'with a nil parameter' do
    options = nil
    expect(described_class.parse(options, nil)).to eq({})
  end

  it 'with an empty hash' do
    options = {}
    expect(described_class.parse(options, nil)).to eq({})
  end

  context 'when setting retirement date' do
    describe 'retires_on' do
      it 'with invalid time' do
        options = {'dialog_service_retires_on' => 'xyz'}
        parsed_results = described_class.parse(options, nil)

        expect(parsed_results[:retires_on]).to be_nil
        expect(parsed_results[:retirement_warn]).to be_nil
      end

      it 'with valid time' do
        Timecop.freeze(time) do
          options = {'dialog_service_retires_on' => time.to_s}
          parsed_results = described_class.parse(options, nil)

          expect(parsed_results[:retires_on]).to eq(time)
          expect(parsed_results[:retirement_warn]).to be_nil
        end
      end

      it 'with an invalid date that has already past' do
        Timecop.freeze(time) do
          options = {'dialog_service_retires_on' => "2000-01-01"}
          parsed_results = described_class.parse(options, nil)

          expect(parsed_results[:retires_on]).to be_nil
          expect(parsed_results[:retirement_warn]).to be_nil
        end
      end
    end

    describe 'retires_in_hours' do
      it 'with invalid time' do
        options = {'dialog_service_retires_in_hours' => 'xyz'}
        parsed_results = described_class.parse(options, nil)

        expect(parsed_results[:retires_on]).to be_nil
        expect(parsed_results[:retirement_warn]).to be_nil
      end

      it 'with valid time' do
        Timecop.freeze(time) do
          options = {'dialog_service_retires_in_hours' => 5}
          parsed_results = described_class.parse(options, nil)

          expect(parsed_results[:retires_on]).to eq(time + 5.hours)
          expect(parsed_results[:retirement_warn]).to be_nil
        end
      end
    end

    describe 'retires_in_days' do
      it 'with invalid time' do
        options = {'dialog_service_retires_in_days' => 'xyz'}
        parsed_results = described_class.parse(options, nil)

        expect(parsed_results[:retires_on]).to be_nil
        expect(parsed_results[:retirement_warn]).to be_nil
      end

      it 'with valid time' do
        Timecop.freeze(time) do
          options = {'dialog_service_retires_in_days' => 5}
          parsed_results = described_class.parse(options, nil)

          expect(parsed_results[:retires_on]).to eq(time + 5.days)
          expect(parsed_results[:retirement_warn]).to be_nil
        end
      end
    end
  end

  context 'when setting retirement warn date' do
    it 'with retirement_warn_on' do
      user = FactoryGirl.create(:user)
      expect(user).to receive(:with_my_timezone).exactly(3).times.and_yield

      Timecop.freeze(time) do
        options = {'dialog_service_retires_in_days'    => 5,
                   'dialog_service_retirement_warn_on' => (time + 1.day).to_s}
        parsed_results = described_class.parse(options, user)

        expect(parsed_results[:retires_on]).to eq(time + 5.days)
        expect(parsed_results[:retirement_warn]).to eq(time + 1.day)
      end
    end

    it 'with retirement_warn_in_days' do
      Timecop.freeze(time) do
        options = {'dialog_service_retires_in_days'         => 5,
                   'dialog_service_retirement_warn_in_days' => 1}
        parsed_results = described_class.parse(options, nil)

        expect(parsed_results[:retires_on]).to eq(time + 5.days)
        expect(parsed_results[:retirement_warn]).to eq(time + 1.day)
      end
    end

    it 'with retirement_warn_offset_days' do
      Timecop.freeze(time) do
        options = {'dialog_service_retires_in_days'             => 5,
                   'dialog_service_retirement_warn_offset_days' => 4}
        parsed_results = described_class.parse(options, nil)

        expect(parsed_results[:retires_on]).to eq(time + 5.days)
        expect(parsed_results[:retirement_warn]).to eq(time + 1.day)
      end
    end

    it 'with retirement_warn_in_hours' do
      Timecop.freeze(time) do
        options = {'dialog_service_retires_in_hours'         => 5,
                   'dialog_service_retirement_warn_in_hours' => 1}
        parsed_results = described_class.parse(options, nil)

        expect(parsed_results[:retires_on]).to eq(time + 5.hours)
        expect(parsed_results[:retirement_warn]).to eq(time + 1.hour)
      end
    end

    it 'with retirement_warn_offset_hours' do
      Timecop.freeze(time) do
        options = {'dialog_service_retires_in_hours'             => 5,
                   'dialog_service_retirement_warn_offset_hours' => 4}
        parsed_results = described_class.parse(options, nil)

        expect(parsed_results[:retires_on]).to eq(time + 5.hours)
        expect(parsed_results[:retirement_warn]).to eq(time + 1.hour)
      end
    end
  end
end
