module Lita
  module Handlers
    class Gitlab2jenkinsGhp < Handler

      def self.default_config(config)
        config.default_room = '#general'
        config.grourp = 'group_name'
        config.gitlab_url = 'http://example.gitlab'
        config.gitlab_private_token = 'orwejnweuf'
        config.jenkins_url = 'http://example.jenkins'
        config.jenkins_hook = '/gitlab/build'
      end

      http.post '/lita/gitlab2jenkinsghp', :receive

      def receive(request, response)
        json_body = request.params['payload'] || extract_json_from_request(request)
        data = symbolize parse_payload(json_body)
        data[:project] = request.params['project']
        message = format_message(data)

        if message
          targets = request.params['targets'] || Lita.config.handlers.gitlab2jenkinsghp.default_room
          rooms = []
          targets.split(',').each do |param_target|
            rooms << param_target
          end
          rooms.each do |room|
            target = Source.new(room: room)
            robot.send_message(target, message)
          end
        end
      end

      private

      def extract_json_from_request(request)
        request.body.rewind
        request.body.read
      end

      def parse_payload(payload)
        MultiJson.load(payload)
        rescue MultiJson::LoadError => e
        Lita.logger.error("Could not parse JSON payload from Github: #{e.message}")
        return
      end

      def symbolize(obj)
        return obj.inject({}){|memo,(k,v)| memo[k.to_sym] =  symbolize(v); memo} if obj.is_a? Hash
        return obj.inject([]){|memo,v    | memo           << symbolize(v); memo} if obj.is_a? Array
        return obj
      end

      def format_message(data)
        data.key?(:event_name) ? web_message(data)
      end

      def web_message(data)
        if data.key? :object_kind
          # Merge has target branch
          (data[:object_attributes].key? :target_branch) ? build_merge_message(data)
        else
          # Push has no object kind
          build_branch_message(data)    # Using as a push events identifier
        end
      rescue
        Lita.logger.warn "Error formatting message: #{data.inspect}"
      end

      def build_branch_message(data)
        if data[:before] =~ /^0+$/
          redis.set(data[:commits][0][:id], data)
        end
      rescue
        Lita.logger.warn "Error formatting message: #{data.inspect}"
      end

      def build_merge_message(data)
        Lita.logger.warn "Error formatting message: #{data.inspect}"
      end

      def interpolate_message(key, data)
        t(key) % data
      end

    end

    Lita.register_handler(Gitlab2jenkinsGhp)
  end
end
