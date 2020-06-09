# frozen_string_literal: true

module Actions
  module Messages
    # long-polling implementation
    class GetLong < Base::Action
      def call
        loop do
          event = Events::NewMessage.pull(for: params.user_id)

          if event.empty?
            sleep(1)
            next
          end

          return event.to_json
        end
      end
    end
  end
end
