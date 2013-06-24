module ActsAsSplittable

  module Splittable

    def split_column_values!(columns = nil)
      splittable_aggregate_columns(columns) do |column, splitter|
        value = __send__(column) or next

        values = splitter.split(value, self)
        splitter.partials.each_with_index do |partial, index|
          __send__ :"#{partial}=", values[index]
        end
        reset_splittable_changed_partials splitter.partials
      end
      self
    end

    def join_column_values!(columns = nil)
      splittable_aggregate_columns(columns) do |column, splitter|
        values = splitter.partials.map {|partial| __send__(partial) }
        next if values.include?(nil)

        __send__ :"#{column}=", splitter.restore(values, self)
        reset_splittable_changed_partials splitter.partials
      end
      self
    end

    def splittable_partials
      @splittable_partials ||= {}
    end

    protected

    attr_writer :splittable_changed_partials

    def splittable_changed_partials
      @splittable_changed_partials ||= []
    end

    def splittable_changed_partial?(partial)
      splittable_changed_partials.include? partial
    end

    def reset_splittable_changed_partials(partials)
      self.splittable_changed_partials.uniq!
      self.splittable_changed_partials -= partials
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

  end

end
