# frozen_string_literal: true

module Events
  module NewMessage
    class << self
      def push(for: nil)
        App.redis.set()
      end

      def pull(for: nil)
        App.redis.get()
      end
    end
  end
end
