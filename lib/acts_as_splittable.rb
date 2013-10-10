$LOAD_PATH.unshift File.dirname(__FILE__)

require 'active_record'
require 'acts_as_splittable/utility'
require 'acts_as_splittable/splittable'
require 'acts_as_splittable/attributes'
require 'acts_as_splittable/splitter'
require 'acts_as_splittable/config'

module ActsAsSplittable
  class << self
    DEFAULT_OPTIONS = {
      callbacks:       true,
      predicates:      false,
      join_on_change:  false,
      split_on_change: false,
      allow_nil:       false,
      dirty:           false,
    }

    def default_options(*args)
      case args.length
      when 0
        @default_options ||= DEFAULT_OPTIONS
      when 1
        self.default_options = args.first
      else
        raise ArgumentError, "wrong number of arguments (#{args.length} for 0..1)"
      end
    end

    def default_options=(options)
      default_options.merge! options
    end
  end

  def acts_as_splittable(options = {})
    options = options.reverse_merge ActsAsSplittable.default_options

    extend  ClassMethods
    include Splittable
    include splittable_module

    @splittable_options = options

    if splittable_options[:callbacks]
      after_initialize { new_record? or split_column_values! }
      before_save      { join_column_values! }
    end
  end

  def acts_as_hasty_splittable(options = {})
    acts_as_splittable options.reverse_merge(join_on_change: true, split_on_change: true, callbacks: false)
  end

  module ClassMethods
    def splittable_options
      @splittable_options ||= {}
    end

    def with_splittable_options(other_options = {})
      old = splittable_options
      @splittable_options = old.merge(other_options)
      Proc.new.(splittable_options)
    ensure
      @splittable_options = old
    end

    def splittable_config
      @splittable_config ||= Config.new
    end

    def splittable_attributes_class
      @splittable_attributes_class ||= Class.new(Attributes)
    end

    def splittable(column, options)
      options  = options.merge(name: column.to_sym)
      splitter = Splitter.new(self, options)

      splittable_config.splitters << splitter

      splitter.attributes.each do |attribute|
        splittable_attributes_class.define attribute

        define_splittable_getter(attribute)
        define_splittable_setter(attribute, splitter)
        define_splittable_predicator(attribute) if splitter.predicates?
        define_splittable_dirty(attribute) if splitter.dirty?

        if splitter.predicates? and not splitter.dirty?
          Utility.alias_methods_with_warning_for splittable_module do
            alias_method :"#{attribute}_changed?", :"#{attribute}_synced?"
          end
        end
      end

      if splittable_options[:split_on_change]
        define_splittable_setter_hook(splitter.name)
      end
    end

    def inherited(child)
      super
      child.__send__ :instance_variable_set, :@splittable_options, splittable_options.dup
      child.__send__ :instance_variable_set, :@splittable_module, splittable_module.dup
      child.__send__ :instance_variable_set, :@splittable_attributes_class, splittable_attributes_class.dup
      child.__send__ :include, child.splittable_module
      child.splittable_config.inherit! splittable_config
    end

    protected

    def splittable_module
      @splittable_module ||= Module.new
    end

    private

    def define_splittable_method(name, &block)
      splittable_module.__send__ :define_method, name, &block
    end

    def define_splittable_getter(attribute)
      define_splittable_method attribute do
        splittable_attributes[attribute]
      end
    end

    def define_splittable_setter(attribute, splitter)
      define_splittable_method :"#{attribute}=" do |value|
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
      define_splittable_method :"#{attribute}_synced?" do
        splittable_changed_attribute? attribute
      end
    end

    def define_splittable_setter_hook(name)
      define_splittable_method "#{name}=" do |value|
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

    def define_splittable_dirty(attribute)
      splittable_attributes_class.define_dirty_attribute_method attribute

      %w(change changed? was will_change!).each do |suffix|
        name = :"#{attribute}_#{suffix}"
        define_splittable_method(name) {|*args| splittable_attributes.__send__ name, *args }
      end
    end
  end
end

ActiveRecord::Base.extend ActsAsSplittable
