require 'spec_helper'

shared_examples_for 'splittable' do
  before :each do
    @splittable1               = described_class.new(name: "#{described_class.name} 1")
    @splittable1.email_local   = 'splittable'
    @splittable1.email_domain  = 'example.com'
    @splittable1.postal_code1  = '012'
    @splittable1.postal_code2  = '3456'
    @splittable1.phone_number1 = '012'
    @splittable1.phone_number2 = '3456'
    @splittable1.phone_number3 = '7890'
    @splittable1.save!

    @splittable2 = described_class.create!(
      name:          "#{described_class.name} 2",
      email_local:   'splittable',
      email_domain:  'example.com',
      postal_code1:  '012',
      postal_code2:  '3456',
      phone_number1: '012',
      phone_number2: '3456',
      phone_number3: '7890',
    )

    @splittables = [@splittable1, @splittable2]
  end

  it 'should assign attributes' do
    @splittables.each do |record|
      record.assign_attributes(postal_code1: '987', postal_code2: '6543')

      record.postal_code1.should == '987'
      record.postal_code2.should == '6543'
    end
  end

  it 'should join partials before save' do
    @splittables.each do |record|
      record.email.should        == 'splittable@example.com'
      record.postal_code.should  == '0123456'
      record.phone_number.should == '01234567890'
    end
  end

  it 'should split columns after initialize' do
    @splittables.each do |record|
      splittable = described_class.find(record.id)

      splittable.email_local.should   == 'splittable'
      splittable.email_domain.should  == 'example.com'
      splittable.postal_code1.should  == '012'
      splittable.postal_code2.should  == '3456'
      splittable.phone_number1.should == '012'
      splittable.phone_number2.should == '3456'
      splittable.phone_number3.should == '7890'
    end
  end

  context 'when nil includes in partials or value of column is nil' do
    before :each do
      @splittable1 = described_class.new(name: "#{described_class.name} 1")
      @splittable1.save!

      @splittable2 = described_class.create!(
        name: "#{described_class.name} 2"
      )

      @splittables = [@splittable1, @splittable2]
    end

    it 'should not join partials before save' do
      @splittables.each do |record|
        record.email.should be_nil
      end
    end

    it 'should not split columns after initialize' do
      @splittables.each do |record|
        splittable = described_class.find(record.id)

        splittable.email_local.should be_nil
        splittable.email_domain.should be_nil
      end
    end
  end
end

shared_examples_for 'splittable with callbacks' do

  describe '#*_unsynced?' do
    before do
      @splittable = described_class.new
    end

    it 'should return true when value is changed until #split_column_values! or #join_column_values! is called' do
      @splittable.email_local_unsynced?.should_not  be_true
      @splittable.email_domain_unsynced?.should_not be_true

      @splittable.email_local = 'splittable'
      @splittable.email_local_unsynced?.should be_true

      @splittable.email_domain = 'example.com'
      @splittable.email_domain_unsynced?.should be_true

      @splittable.join_column_values!

      @splittable.email_local_unsynced?.should_not  be_true
      @splittable.email_domain_unsynced?.should_not be_true

      @splittable.email_local = nil
      @splittable.email_local_unsynced?.should be_true

      @splittable.email_domain = nil
      @splittable.email_domain_unsynced?.should be_true

      @splittable.split_column_values!

      @splittable.email_local_unsynced?.should_not  be_true
      @splittable.email_domain_unsynced?.should_not be_true
    end
  end

end

describe Splittable do
   it_behaves_like 'splittable'
   it_behaves_like 'splittable with callbacks'

   context 'when was given a proc to callbacks' do
    it 'should call in the record' do
      model_class = Class.new(ActiveRecord::Base) do
        self.table_name = :splittables

        acts_as_splittable

        splittable :birthday, {
          partials: [:birthday_year, :birthday_month, :birthday_day],

          on_split: -> (value) {
            year, month, day = value.chars.each_slice(2).map(&:join).map(&:to_i)
            [year + birthday_base, month, day]
          },

          on_join: -> (values) {
            year, month, day = values.map(&:to_i)
            '%02d%02d%02d' % [year - birthday_base, month, day]
          }
        }

        def birthday_base
          birthday_era == 'showa' ? 1925 : birthday_era == 'heisei' ? 1988 : 0
        end
      end

      model = model_class.create!(
        birthday_era:   'heisei',
        birthday_year:  1989,
        birthday_month: 7,
        birthday_day:   7
      )

      model.birthday = '010707'

      model = model_class.find(model.id)

      model.birthday_year.should  == 1989
      model.birthday_month.should == 7
      model.birthday_day.should   == 7
    end
  end
end


describe SplittableInherited do
  it_behaves_like 'splittable'
  it_behaves_like 'splittable with callbacks'
end


describe SplittableInheritedInherited do
  it_behaves_like 'splittable'
  it_behaves_like 'splittable with callbacks'
end


describe SplittableSplitOrJoinOnChange do

  it 'should join partials when one of partials is set and all of them are not nil' do
    splittable = SplittableSplitOrJoinOnChange.new

    splittable.email_local  = 'splittable'
    splittable.email_domain = 'example.com'

    splittable.email.should == 'splittable@example.com'

    splittable.email = nil

    splittable.phone_number1       = '012'
    splittable.phone_number.should be_nil

    splittable.phone_number2       = '3456'
    splittable.phone_number.should be_nil

    splittable.phone_number3       = '7890'
    splittable.phone_number.should == '012-3456-7890'

    splittable.phone_number3       = '0000'
    splittable.phone_number.should == '012-3456-0000'

    splittable.email.should be_nil
  end

  it 'should split value when value is set' do
    splittable1 = SplittableSplitOrJoinOnChange.new(
      email:        'splittable@example.com',
      phone_number: '012-3456-7890',
    )

    splittable2              = SplittableSplitOrJoinOnChange.new
    splittable2.email        = 'splittable@example.com'
    splittable2.phone_number = '012-3456-7890'

    [splittable1, splittable2].each do |splittable|
      splittable.email_local.should   == 'splittable'
      splittable.email_domain.should  == 'example.com'
      splittable.phone_number1.should == '012'
      splittable.phone_number2.should == '3456'
      splittable.phone_number3.should == '7890'
    end

    splittable1.phone_number = '000-0000-0000'

    splittable1.phone_number1.should == '000'
    splittable1.phone_number2.should == '0000'
    splittable1.phone_number3.should == '0000'
  end

end

describe SplittableSplitOrJoinOnChangeWithAliasAttribute do

  it 'should split value when value is set' do
    splittable1 = SplittableSplitOrJoinOnChangeWithAliasAttribute.new(
      email_address:        'splittable@example.com',
    )

    splittable2               = SplittableSplitOrJoinOnChangeWithAliasAttribute.new
    splittable2.email_address = 'splittable@example.com'

    [splittable1, splittable2].each do |splittable|
      splittable.email_local.should   == 'splittable'
      splittable.email_domain.should  == 'example.com'
    end

    splittable1.email_address = 'splittable1@1.example.com'

    splittable1.email_local.should   == 'splittable1'
    splittable1.email_domain.should  == '1.example.com'
  end

end

describe SplittableUseDelimiter do

  let (:splittable) do
    SplittableUseDelimiter.new(email: 'splittable@example.com')
  end

  it 'should split value when value is set' do
    splittable.email_local.should == 'splittable'
    splittable.email_domain.should == 'example.com'
  end

  it 'should join partials before save' do
    splittable.email_local  = 'splittable+1'
    splittable.email_domain = 'mail.example.com'
    splittable.email.should == 'splittable+1@mail.example.com'
  end

end

describe SplittableUseTypeCasting do

  shared_examples_for 'splittable typecasting' do

    it 'should typecast' do
      splittable.lat.should == 35.629902
      splittable.lng.should == 139.793934
    end

    it 'should restore' do
      splittable.lat = 51.476877
      splittable.lng = -0.00033
      splittable.latlng.should == '51.476877,-0.00033'
    end

  end

  context 'with method' do
    let (:splittable) do
      Class.new(SplittableUseTypeCasting) {
        splittable :latlng, delimiter: ',', attributes: [:lat, :lng], type: Float
      }.new(latlng: '35.629902,139.793934')
    end

    it_behaves_like 'splittable typecasting'
  end

  context 'with Proc' do
    let (:splittable) do
      Class.new(SplittableUseTypeCasting) {
        splittable :latlng, delimiter: ',', attributes: [:lat, :lng], type: Proc.new{|value| value.to_f }
      }.new(latlng: '35.629902,139.793934')
    end

    it_behaves_like 'splittable typecasting'
  end

  context 'with Symbol' do
    let (:splittable) do
      Class.new(SplittableUseTypeCasting) {
        splittable :latlng, delimiter: ',', attributes: [:lat, :lng], type: :to_f
      }.new(latlng: '35.629902,139.793934')
    end

    it_behaves_like 'splittable typecasting'
  end

end

describe SplittableNotAllowNil do
  it "should join columns" do
    splittable = described_class.new(email_local: 'splittable', email_domain: 'example.com').join_column_values!
    splittable.email.should_not be_nil
  end

  it "should not join columns" do
    splittable = described_class.new(email_local: 'splittable', email_domain: nil).join_column_values!
    splittable.email.should be_nil
  end

  it "should split columns" do
    splittable = described_class.new(email: 'splittable@example.com').split_column_values!
    splittable.email_local.should == 'splittable'
    splittable.email_domain.should == 'example.com'
  end

  it "should not split columns" do
    splittable = described_class.new(email: nil, email_local: 'splittable', email_domain: 'example.com').split_column_values!
    splittable.email_local.should == 'splittable'
    splittable.email_domain.should == 'example.com'
  end

  context "when option `allow_nil' is overridden." do
    it "should join columns" do
      splittable = described_class.new(email_sub_local: 'splittable', email_sub_domain: nil).join_column_values!
      splittable.email_sub.should == 'splittable@'
    end

    it "should split columns" do
      splittable = described_class.new(email_sub: nil, email_sub_local: 'splittable', email_sub_domain: 'example.com').split_column_values!
      splittable.email_sub_local.should be_nil
      splittable.email_sub_domain.should be_nil
    end
  end
end

describe SplittableAllowNil do
  it "should join columns" do
    splittable = described_class.new(email_local: 'splittable', email_domain: nil).join_column_values!
    splittable.email.should == 'splittable@'
  end

  it "should split columns" do
    splittable = described_class.new(email: nil, email_local: 'splittable', email_domain: 'example.com').split_column_values!
    splittable.email_local.should be_nil
    splittable.email_domain.should be_nil
  end

  context "when option `allow_nil' is overridden." do
    it "should not join columns" do
      splittable = described_class.new(email_sub_local: 'splittable', email_sub_domain: nil).join_column_values!
      splittable.email_sub.should be_nil
    end

    it "should not split columns" do
      splittable = described_class.new(email_sub: nil, email_sub_local: 'splittable', email_sub_domain: 'example.com').split_column_values!
      splittable.email_sub_local.should == 'splittable'
      splittable.email_sub_domain.should == 'example.com'
    end
  end
end

describe SplittableDirty do
  it_behaves_like 'splittable'

  let(:splittable_new)   { described_class.new }
  let(:splittable_saved) { described_class.create!(email_local: 'splittable', email_domain: 'example.com') }

  describe "*_change, *_was, *_changed?" do
    context "new record" do
      it "should be unchanged" do
        splittable_new.email_local_change.should   be_nil
        splittable_new.email_local_was.should      be_nil
        splittable_new.email_local_changed?.should be_false
      end

      it "should be unchanged first" do
        splittable_new.email_local = 'first value'
        splittable_new.email_local_change.should   be_nil
        splittable_new.email_local_was.should      == 'first value'
        splittable_new.email_local_changed?.should be_false
      end

      it "should be changed from the second time" do
        splittable_new.email_local  = 'first value'
        splittable_new.email_local  = 'second value'

        splittable_new.email_local_change.should   == ['first value', 'second value']
        splittable_new.email_local_was.should      == 'first value'
        splittable_new.email_local_changed?.should be_true

        splittable_new.email_local = 'third value'

        splittable_new.email_local_change.should   == ['first value', 'third value']
        splittable_new.email_local_was.should      == 'first value'
        splittable_new.email_local_changed?.should be_true
      end

      it "should ignore if first value is nil" do
        splittable_new.email_local = nil
        splittable_new.email_local = 'second value'
        
        splittable_new.email_local_change.should   be_nil
        splittable_new.email_local_was.should      == 'second value'
        splittable_new.email_local_changed?.should be_false
      end
    end

    context "existent record" do
      it "should be unchanged" do
        splittable_saved.email_local.should        == 'splittable'
        splittable_saved.email_local_change.should be_nil
        splittable_saved.email_local_was.should      == 'splittable'
        splittable_saved.email_local_changed?.should be_false
      end

      it "should be changed" do
        splittable_saved.email_local = 'splittable2'
        splittable_saved.email_local_change.should   == ['splittable', 'splittable2']
        splittable_saved.email_local_was.should      == 'splittable'
        splittable_saved.email_local_changed?.should be_true
      end
    end

    it "should be reset after save" do
      splittable_saved.email_local = 'splittable2'

      splittable_saved.email_local_changed?.should be_true

      splittable_saved.save!

      splittable_saved.email_local_changed?.should be_false
      splittable_saved.splittable_attributes.previous_changes.should == {'email_local' => ['splittable', 'splittable2']}

      splittable_saved.save!

      splittable_saved.splittable_attributes.previous_changes.should == {}
    end
  end
end
