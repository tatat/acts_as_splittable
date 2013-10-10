module ActsAsSplittable
  class Attributes < Hash
    class << self
      def child
        Class.new Attributes
      end

      def dirty!
        unless dirty?
          include ActiveModel::Dirty
          include Dirty
        end

        self
      end

      def dirty?
        include? ActiveModel::Dirty
      end

      def define(name)
        name = name.to_sym
        define_method(name) { self[name] }
      end

      def define_dirty_attribute_method(name)
        dirty!.define_attribute_method name
      end
    end

    def []=(key, value)
      key = key.to_sym

      if dirty?
        return if not key?(key) and value.nil?
        __send__ :"#{key}_will_change!" if key?(key) and value != self[key]
      end

      super
    end

    def [](key)
      super key.to_sym
    end

    def dirty?
      @dirty = self.class.dirty? if @dirty.nil?
      @dirty
    end

    def changed!; super if defined?(super) end
    def reset!; super if defined?(super) end

    module Dirty
      def changed!
        @previously_changed = changes
        @changed_attributes = changed_attributes.class.new
      end

      def reset!
        @previously_changed = changed_attributes.class.new
        @changed_attributes = changed_attributes.class.new
      end

      def initialize_copy(original)
        super
        @previously_changed = original.__send__(:instance_variable_get, :@previously_changed).dup
        @changed_attributes = original.__send__(:instance_variable_get, :@changed_attributes).dup
      end
    end
  end
end