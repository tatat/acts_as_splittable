require 'spec_helper'

[Splittable, SplittableInherited, SplittableInheritedInherited].each do |klass|
  describe klass do

    before :each do
      @splittable1               = klass.new(name: "#{klass.name} 1")
      @splittable1.email_local   = 'splittable'
      @splittable1.email_domain  = 'example.com'
      @splittable1.postal_code1  = '012'
      @splittable1.postal_code2  = '3456'
      @splittable1.phone_number1 = '012'
      @splittable1.phone_number2 = '3456'
      @splittable1.phone_number3 = '7890'
      @splittable1.save!

      @splittable2 = klass.create!(
        name:          "#{klass.name} 2",
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
        splittable = Splittable.find(record.id)

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
        @splittable1 = klass.new(name: "#{klass.name} 1")
        @splittable1.save!

        @splittable2 = klass.create!(
          name: "#{klass.name} 2"
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
          splittable = Splittable.find(record.id)

          splittable.email_local.should be_nil
          splittable.email_domain.should be_nil
        end
      end
    end
  end
end

describe Splittable do
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
