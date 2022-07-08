module Z3
  class Model
    def initialize(model : LibZ3::Model)
      @model = model
    end

    {% for type in %w[BoolExpr IntExpr BitvecExpr RealExpr] %}
      def eval(expr : {{type.id}}, complete=false)
        result = API.model_eval(self, expr, complete)
        raise Z3::Exception.new("Incorrect type returned") unless result.is_a?({{type.id}})
        result
      end
    {% end %}

    def [](expr)
      eval(expr, true)
    end

    # This needs to go eventually
    def to_s(io)
      io << API.model_to_string(@model).chomp
    end

    def to_unsafe
      @model
    end
  end
end
