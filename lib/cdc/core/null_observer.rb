# frozen_string_literal: true

module CDC
  module Core
    # No-op observer for callers that do not need instrumentation.
    class NullObserver < Observer
      INSTANCE = new

      private_class_method :new
    end
  end
end
