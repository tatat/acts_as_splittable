EMAIL_SPLIT_PATTERN = /\A(?<email_local>[^@]+)@(?<email_domain>[^@]+)\Z/
EMAIL_JOIN_PROCESS  = Proc.new{|values| values.join('@') }

class Splittable < ActiveRecord::Base

  acts_as_splittable predicates: true

  splittable :email,        split: ['@', 2], attributes: [:email_local, :email_domain], on_join: EMAIL_JOIN_PROCESS
  splittable :postal_code,  pattern: /\A(?<postal_code1>[0-9]{3})(?<postal_code2>[0-9]{4})\Z/
  splittable :phone_number, attributes: [:phone_number1, :phone_number2, :phone_number3], on_split: :split_phone_number, on_join: :join_phone_number

  protected

  def split_phone_number(value)
    return if value.nil?
    [value[0, 3], value[3, 4], value[7, 4]]
  end

  def join_phone_number(values)
    values.join
  end
end

class SplittableInherited < Splittable; end
class SplittableInheritedInherited < SplittableInherited; end

class SplittableWithValidation < ActiveRecord::Base
  self.table_name = 'splittables'

  acts_as_splittable

  splittable :email, pattern: EMAIL_SPLIT_PATTERN, on_join: EMAIL_JOIN_PROCESS

  validates :email_local,  format: { with: /\A[a-zA-Z0-9_.-]+\Z/ }
  validates :email_domain, format: { with: /\A(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,4}\Z/ }
end

class SplittableWithValidationForOriginalColumn < ActiveRecord::Base
  self.table_name = 'splittables'

  acts_as_splittable callbacks: false

  splittable :email, pattern: EMAIL_SPLIT_PATTERN, on_join: EMAIL_JOIN_PROCESS

  validates :email, format: { with: /\A[a-zA-Z0-9_.-]+@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,4}\Z/ }
end

class SplittableSplitOrJoinOnChange < ActiveRecord::Base
  self.table_name = 'splittables'

  acts_as_hasty_splittable
  # same as `acts_as_splittable join_on_change: true, split_on_change: true, callbacks: false`

  splittable :email, pattern: EMAIL_SPLIT_PATTERN, on_join: EMAIL_JOIN_PROCESS

  splittable :phone_number,
    pattern: /\A(?<phone_number1>\d{3})-(?<phone_number2>\d{4})-(?<phone_number3>\d{4})\Z/,
    on_join: ->(values) { values.join '-' }
end

class SplittableSplitOrJoinOnChangeWithAliasAttribute < ActiveRecord::Base
  self.table_name = 'splittables'

  acts_as_splittable join_on_change: true, split_on_change: true, callbacks: false

  splittable :email, pattern: EMAIL_SPLIT_PATTERN, on_join: EMAIL_JOIN_PROCESS

  alias_attribute :email_address, :email
end

class SplittableUseDelimiter < ActiveRecord::Base
  self.table_name = 'splittables'

  acts_as_splittable join_on_change: true, split_on_change: true, callbacks: false

  splittable :email, delimiter: '@', attributes: [:email_local, :email_domain]
end

class SplittableUseTypeCasting < ActiveRecord::Base
  self.table_name = 'splittables'

  acts_as_hasty_splittable
end

class SplittableBase < ActiveRecord::Base
  self.table_name = 'splittables'

  def self.define_splittable(options = {})
    acts_as_splittable options
    splittable :email, delimiter: '@', attributes: [:email_local, :email_domain]
  end
end

class SplittableSuppressOnNil < SplittableBase; define_splittable end
class SplittableNotSuppressOnNil < SplittableBase; define_splittable suppress_on_nil: false end
