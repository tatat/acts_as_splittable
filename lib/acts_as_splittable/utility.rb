module ActsAsSplittable
  module Utility
    module_function

    def alias_methods_with_warning_for(mod, &block)
      AliasWithWarning.new(mod).instance_exec &block
    end

    def deprecation_warning_of_method_name(old_name, new_name)
       warn "DEPRECATION WARNING: `#{old_name}' is deprecated. Please use `#{new_name}' instead."
    end

    class AliasWithWarning < Struct.new(:mod)
      def alias_method(new_name, original_name)
        mod.__send__ :define_method, new_name do |*args|
          Utility.deprecation_warning_of_method_name new_name, original_name
          __send__ original_name, *args
        end
      end

      def method_missing(name, *args)
        mod.__send__ name, *args
      end
    end
  end
end