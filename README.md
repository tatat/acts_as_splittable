ActsAsSplittable
====================

Create virtual attributes.

Installation
--------------------

Add this line to your application's Gemfile:

```ruby
gem 'acts_as_splittable'
```

And then execute:

```
$ bundle
```

Or install it yourself as:

```
$ gem install acts_as_splittable
```


Usage
--------------------


```ruby
class Splittable < ActiveRecord::Base

  acts_as_splittable

  splittable :email,        split: ['@', 2], attributes: [:email_local, :email_domain], on_join: Proc.new{|values| values.join('@') }
  splittable :postal_code,  pattern: /\A(?<postal_code1>[0-9]{3})(?<postal_code2>[0-9]{4})\Z/
  splittable :phone_number, attributes: [:phone_number1, :phone_number2, :phone_number3], on_split: :split_phone_number, on_join: :join_phone_number

  validates :email_local,   format: { with: /\A[a-zA-Z0-9_.-]+\Z/ }
  validates :email_domain,  format: { with: /\A(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,4}\Z/ }
  validates :postal_code1,  format: { with: /\A[0-9]{3}\Z/ }
  validates :postal_code2,  format: { with: /\A[0-9]{4}\Z/ }
  validates :phone_number1, format: { with: /\A[0-9]{3}\Z/ }
  validates :phone_number2, format: { with: /\A[0-9]{4}\Z/ }
  validates :phone_number3, format: { with: /\A[0-9]{4}\Z/ }

  protected

  def split_phone_number(value)
    return if value.nil?
    [value[0, 3], value[3, 4], value[7, 4]]
  end

  def join_phone_number(values)
    values.join
  end
end
```

then

```ruby
splittable = Splittable.create!(
  email_local:   'splittable',
  email_domain:  'example.com',
  postal_code1:  '012',
  postal_code2:  '3456',
  phone_number1: '012',
  phone_number2: '3456',
  phone_number3: '7890',
)

p splittable.email        #=> "splittable@example.com"
p splittable.postal_code  #=> "0123456"
p splittable.phone_number #=> "01234567890"
```

or

```ruby
splittable               = Splittable.new
splittable.email_local   = 'splittable'
splittable.email_domain  = 'example.com'
splittable.postal_code1  = '012'
splittable.postal_code2  = '3456'
splittable.phone_number1 = '012'
splittable.phone_number2 = '3456'
splittable.phone_number3 = '7890'

splittable.save!
```

### Manualy

```ruby
class Splittable < ActiveRecord::Base
  
  # callbacks are
  #   after_initialize { new_record? or split_column_values! }
  #   before_save      { join_column_values! }
  acts_as_splittable callbacks: false

  splittable :email, pattern: /\A(?<email_local>[^@]+)@(?<email_domain>[^@]+)\Z/, on_join: Proc.new{|values| values.join('@') }

  validates :email, presence: true
end
```

then

```ruby
splittable = Splittable.new(
  email_local:   'splittable',
  email_domain:  'example.com',
)

p splittable.email  #=> nil
p splittable.valid? #=> false

splittable.join_column_values!

p splittable.email  #=> "splittable@example.com"
p splittable.valid? #=> true
```

and

```ruby
splittable = Splittable.find(splittable_id)

p splittable.email_local  #=> nil
p splittable.email_domain #=> nil

splittable.split_column_values!

p splittable.email_local  #=> "splittable"
p splittable.email_domain #=> "example.com"
```

### Automatically (without callbacks)

```ruby
class Splittable < ActiveRecord::Base
  
  acts_as_hasty_splittable
  # same as `acts_as_splittable split_on_change: true, join_on_change: true, callbacks: false`

  # ...
end
```

then

```ruby
splittable = Splittable.new(
  email_local:   'splittable',
  email_domain:  'example.com',
)

p splittable.email  #=> "splittable@example.com"
p splittable.valid? #=> true
```

and

```ruby
splittable = Splittable.find(splittable_id)

p splittable.email_local  #=> "splittable"
p splittable.email_domain #=> "example.com"
```

### Use Delimiter (Shorthand)

```ruby
class Splittable < ActiveRecord::Base
  
  acts_as_splittable split_on_change: true, join_on_change: true

  splittable :email, delimiter: '@', attributes: [:email_local, :email_domain]
  # :delimiter will be expanded to:
  # {
  #   split: ['@'],
  #   on_join: Proc.new{|values| values.join('@')}
  # }

  # ...
end
```

Options
--------------------

You can change default options

```ruby
ActsAsSplittable.default_options = {
  callbacks:       true,
  predicates:      false,
  join_on_change:  false,
  split_on_change: false,
  allow_nil:       false,
}
```

Contributing
--------------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
