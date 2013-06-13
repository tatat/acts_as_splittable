require 'spec_helper'

describe SplittableWithValidation do
  
  before :each do
    @splittable = SplittableWithValidation.new
  end

  it 'should be valid' do
    @splittable.email_local  = 'splittable'
    @splittable.email_domain = 'example.com'

    @splittable.should be_valid
  end

  it 'should be invalid' do
    @splittable.email_local  = 'splitt@ble'
    @splittable.email_domain = 'example.com'

    @splittable.should_not be_valid
  end

end

describe SplittableWithValidationForOriginalColumn do

  describe '#split_column_values!' do
    before :each do
      @splittable = SplittableWithValidationForOriginalColumn.create!(email: 'splittable@example.com')
    end

    it 'should be nil' do
      @splittable.email_local.should  be_nil
      @splittable.email_domain.should be_nil
    end

    it 'should not be nil' do
      @splittable.split_column_values!
      @splittable.email_local.should_not  be_nil
      @splittable.email_domain.should_not be_nil
    end
  end

  describe '#valid?' do
    before :each do
      @splittable = SplittableWithValidationForOriginalColumn.new
    end

    it 'should be valid' do
      @splittable.email_local  = 'splittable'
      @splittable.email_domain = 'example.com'

      @splittable.join_column_values!.should be_valid
    end

    it 'should be invalid' do
      @splittable.email_local  = 'splitt@ble'
      @splittable.email_domain = 'example.com'

      @splittable.join_column_values!.should_not be_valid
    end
  end
    
end