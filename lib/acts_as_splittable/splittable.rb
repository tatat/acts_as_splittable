module ActsAsSplittable
  module Splittable
    def splittable_attributes
      @splittable_attributes ||= self.class.splittable_attributes_class.new
    end

    def split_column_values!(columns = nil)
      splittable_aggregate_columns(columns) do |column, splitter|
        value = __send__(column)
        next if not splitter.allow_nil? and value.nil?

        values = splitter.split(value, self)
        splitter.attributes.zip(values).each do |key, value|
          __send__ :"#{key}=", value
        end
        reset_splittable_changed_attributes splitter.attributes
      end
      self
    end

    def join_column_values!(columns = nil)
      splittable_aggregate_columns(columns) do |column, splitter|
        values = splitter.attributes.map {|partial| __send__(partial) }
        next if not splitter.allow_nil? and values.include?(nil)

        __send__ :"#{column}=", splitter.restore(values, self)
        reset_splittable_changed_attributes splitter.attributes
      end
      self
    end

    protected

    attr_writer :splittable_changed_attributes

    def splittable_changed_attributes
      @splittable_changed_attributes ||= []
    end

    def splittable_changed_attribute?(attribute)
      splittable_changed_attributes.include? attribute
    end

    def reset_splittable_changed_attributes(attributes)
      self.splittable_changed_attributes.uniq!
      self.splittable_changed_attributes -= attributes
    end

    private

    def splittable_aggregate_columns(columns = nil)
      config = self.class.splittable_config
      columns = columns ? Array(columns) : config.splitters.collect(&:name)
      columns.collect!(&:to_sym)

      columns.collect do |column|
        yield(column, config.splitter(column)) if block_given?
      end
    end

    def splittable_run_callback(callback, *args)
      if callback.is_a?(Proc)
        instance_exec(*args, &callback)
      else
        send(callback, *args)
      end
    end

    Utility.alias_methods_with_warning_for self do
      alias_method :splittable_partials,               :splittable_attributes
      alias_method :splittable_changed_partials,       :splittable_changed_attributes
      alias_method :splittable_changed_partial?,       :splittable_changed_attribute?
      alias_method :reset_splittable_changed_partials, :reset_splittable_changed_attributes

      protected :splittable_changed_partials, :splittable_changed_partial?, :reset_splittable_changed_partials
    end
  end
end
