require 'active_record'

module ActsAsSplittable

  def acts_as_splittable(options = {})
    options.reverse_merge!(
      callbacks:      true,
      predicates:     false,
      join_on_change: false,
    )

    extend  ClassMethods
    include InstanceMethods

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

  module InstanceMethods

    def split_column_values!(column = nil)
      if column.nil?
        self.class.splittable_columns.each_key{|key| send __method__, key }
      else
        column                                      = column.to_sym
        split, pattern, partials, on_split, on_join = self.class.splittable_columns[column]
        value                                       = send(column)

        unless value.nil?
          values = if on_split
            run_callback(on_split, value)
          elsif value
            if split
              value.to_s.split *(split.is_a?(Array) ? split : [split])
            else
              matches = value.to_s.match(pattern)
              matches[1..(matches.length - 1)]
            end
          end || []

          partials.each_with_index do |partial, index|
            send :"#{partial}=", values[index]
          end

          reset_splittable_changed_partials partials
        end
      end

      self
    end

    def join_column_values!(column = nil)
      if column.nil?
        self.class.splittable_columns.each_key{|key| send __method__, key }
      else
        split, pattern, partials, on_split, on_join = self.class.splittable_columns[column.to_sym]
        values                                      = partials.map{|partial| send(partial) }

        unless values.any?(&:nil?)
          send :"#{column}=", run_callback(on_join, values)
          reset_splittable_changed_partials partials
        end
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

    def run_callback(callback, *args)
      if callback.is_a?(Proc)
        instance_exec(*args, &callback)
      else
        send(callback, *args)
      end
    end
  end
end

ActiveRecord::Base.extend ActsAsSplittable
