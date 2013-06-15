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
