$LOAD_PATH.unshift File.dirname(__FILE__)

require 'active_record'
require 'acts_as_splittable/splittable'
require 'acts_as_splittable/splitter'
require 'acts_as_splittable/config'

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
    attr_writer :splittable_options

    def splittable_options
      @splittable_options ||= {}
    end

    def with_splittable_options(other_options = {})
      old = splittable_options
      self.splittable_options = old.merge(other_options)
      Proc.new.(splittable_options)
    ensure
      self.splittable_options = old
    end

    def splittable_config
      @splittable_config ||= Config.new
    end

    def splittable(column, options)
      options.merge!(name: column.to_sym)
      splitter = Splitter.new(options)
      splittable_config.splitters << splitter

      splitter.attributes.each do |attribute|
        define_splittable_getter(attribute)
        define_splittable_setter(attribute, splitter)
        define_splittable_predicator(attribute) if splittable_options[:predicates]
      end

      if splittable_options[:split_on_change]
        define_splittable_setter_hook(splitter.name)
      end
    end

    def inherited(child)
      super

      child.splittable_options = splittable_options.dup
      child.splittable_config.inherit! splittable_config
    end

    protected

    def splittable_module
      @splittable_module ||= Module.new
    end
    
    private

    def define_splittable_getter(attribute)
      define_method attribute do
        splittable_attributes[attribute]
      end
    end

    def define_splittable_setter(attribute, splitter)
      define_method :"#{attribute}=" do |value|
        splittable_attributes[attribute] = value

        unless splittable_changed_attribute? attribute
          splittable_changed_attributes << attribute
        end

        self.class.with_splittable_options split_on_change: false do |options|
          if options[:join_on_change]
            join_column_values! splitter.name 
          end
        end
      end
    end

    def define_splittable_predicator(attribute)
      define_method :"#{attribute}_changed?" do
        splittable_changed_attribute? attribute
      end
    end

    def define_splittable_setter_hook(name)
      splittable_module.module_eval do
        define_method("#{name}=") do |value|
          if defined?(super)
            super(value)
          elsif respond_to?(:write_attribute, true)
            write_attribute name, value
          end

          self.class.with_splittable_options join_on_change: false do
            split_column_values! name
          end
        end
      end
    end

  end
end

ActiveRecord::Base.extend ActsAsSplittable
