# frozen_string_literal: true

module Actions
  module Messages
    # short-polling implementation
    class GetShort < Base::Action
      def call
        Timeout.timeout(60) do
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
end
