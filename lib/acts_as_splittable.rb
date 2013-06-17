$LOAD_PATH.unshift File.dirname(__FILE__)

require 'active_record'
require 'acts_as_splittable/splittable'

module ActsAsSplittable

  def acts_as_splittable(options = {})
    options.reverse_merge!(
      callbacks:      true,
      predicates:     false,
      join_on_change: false,
    )

    extend  ClassMethods
    include Splittable

    self.splittable_options = options

    if options[:callbacks]
      after_initialize { new_record? or split_column_values! }
      before_save      { join_column_values! }
    end
  end

  module ClassMethods
    SPLITTABLE_DEFAULT_JOIN_PROCESS = Proc.new{|values| values.join }

    attr_writer :splittable_options

    def splittable_options
      @splittable_options ||= {}
    end

    def splittable_columns
      @splittable_columns ||= {}
    end

    def splittable(column, options)
      column                     = column.to_sym
      partials                   = (options[:partials] || options[:pattern].names).map(&:to_sym)
      splittable_columns[column] = [options[:split], options[:pattern], partials, options[:on_split], options[:on_join] || SPLITTABLE_DEFAULT_JOIN_PROCESS]

      partials.each do |partial|
        define_method partial do
          splittable_partials[partial]
        end

        define_method :"#{partial}=" do |value|
          splittable_partials[partial] = value
          splittable_changed_partials << partial unless splittable_changed_partial? partial
          join_column_values! column if self.class.splittable_options[:join_on_change]
        end

        if splittable_options[:predicates]
          define_method :"#{partial}_changed?" do
            splittable_changed_partial? partial
          end
        end
      end
    end

    def inherited(child)
      super

      child.splittable_options = splittable_options.dup
      child.splittable_columns.merge! splittable_columns.dup
    end
  end

end

ActiveRecord::Base.extend ActsAsSplittable
