module ActsAsSplittable
  class Attributes < Hash
    class << self
      def dirty!
        tap { include ActiveModel::Dirty unless dirty? }
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
      return if not key?(key) and value.nil?
      __send__ :"#{key}_will_change!" if dirty? and key?(key) and value != self[key]
      super
    end

    def [](key)
      super key.to_sym
    end

    def dirty?
      @dirty = self.class.dirty? if @dirty.nil?
      @dirty
    end

    def changed!
      if dirty?
        @previously_changed = changes
        @changed_attributes = changed_attributes.class.new
      end
    end

    def reset!
      if dirty?
        @previously_changed = changed_attributes.class.new
        @changed_attributes = changed_attributes.class.new
      end
    end

    def initialize_copy(original)
      @previously_changed = original.__send__(:instance_variable_get, :@previously_changed).dup
      @changed_attributes = original.__send__(:instance_variable_get, :@changed_attributes).dup
    end
  end
end