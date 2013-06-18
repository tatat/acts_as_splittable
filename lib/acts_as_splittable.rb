$LOAD_PATH.unshift File.dirname(__FILE__)

require 'active_record'
require 'acts_as_splittable/splittable'

module ActsAsSplittable

  def acts_as_splittable(options = {})
    options.reverse_merge!(
      callbacks:       true,
      predicates:      false,
      join_on_change:  false,
      split_on_change: false,
    )

    extend  ClassMethods
    include Splittable

    self.splittable_options = options

    if splittable_options[:split_on_change]
      include splittable_module
    end

    if splittable_options[:callbacks]
      after_initialize { new_record? or split_column_values! }
      before_save      { join_column_values! }
    end
  end

  module ClassMethods
    SPLITTABLE_DEFAULT_JOIN_PROCESS = Proc.new{|values| values.join }

    attr_writer :splittable_options

    def splittable_options(other_options = {})
      @splittable_options ||= {}
    end

    def with_splittable_options(other_options = {})
      original_options        = splittable_options
      self.splittable_options = splittable_options.merge(other_options)
      Proc.new.(splittable_options)
      self.splittable_options = original_options
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

          self.class.with_splittable_options split_on_change: false do |options|
            join_column_values! column if options[:join_on_change]
          end
        end

        if splittable_options[:predicates]
          define_method :"#{partial}_changed?" do
            splittable_changed_partial? partial
          end
        end
      end

      if splittable_options[:split_on_change]
        splittable_module.module_eval <<-"EOS"
          def #{column}=(value)
            if defined?(super)
              super
            elsif respond_to?(:write_attribute, true)
              write_attribute :#{column}, value
            end
            
            self.class.with_splittable_options join_on_change: false do
              split_column_values! :#{column}
            end
          end
        EOS
      end
    end

    def inherited(child)
      super

      child.splittable_options = splittable_options.dup
      child.splittable_columns.merge! splittable_columns.dup
    end

    protected

    def splittable_module
      @splittable_module ||= Module.new
    end
  end

end

ActiveRecord::Base.extend ActsAsSplittable
