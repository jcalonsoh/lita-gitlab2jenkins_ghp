module Lita
  module Handlers
    class Gitlab2jenkinsGhp < Handler

      def self.default_config(config)
        config.room                  = '#test2'
        config.group                 = 'group_name'
        config.gitlab_url            = 'http://example.gitlab'
        config.private_token         = 'orwejnweuf'
        config.jenkins_url           = 'http://example.jenkins'
        config.jenkins_hook          = '/gitlab/build'
      end

      http.post '/lita/gitlab2jenkinsghp', :receive

      def receive(request, response)
        json_body = extract_json_from_request(request)
        data = symbolize parse_payload(json_body)
        message = format_message(data)
        room = Lita.config.handlers.gitlab2jenkins_ghp.room
        target = Source.new(room: room)
        robot.send_message(target, message)
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
        if data.has_key? :before
          build_branch_message(data)
        elsif data.has_key? :object_kind
          build_merge_message(data)
        else
          return
        end

      rescue
        Lita.logger.info "Error formatting message on format_message: #{data.inspect}"
      end

      def build_branch_message(data)
        data[:link] = "<#{data[:repository][:homepage]}|#{data[:repository][:name]}>"

        Lita.logger.info "Total Commits: #{data[:total_commits_count]}"
        Lita.logger.info "Commit: #{data[:commits].size}"
        Lita.logger.info "Commit: #{data[:commits][0][:id]}"
        Lita.logger.info "Payload Data: #{data.inspect}"
        redis.set(data[:commits][0][:id], data)
        return "Commit Stored: #{data[:commits][0][:id]}"


      rescue
        Lita.logger.info "Error formatting message on build_branch_message: #{data.inspect}"
      end

      def build_merge_message(data)
        if data[:object_attributes][:state] == 'reopened'
          url_1 =  "#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{data[:object_attributes][:source_project_id]}/"
          url_1 << "repository/branches/#{data[:object_attributes][:source_branch]}"
          url_1 << "?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}"
          request_project = http.get(url_1)
          gitlab_data = parse_payload(symbolize request_project.body)
          get_redis << gitlab_data["commit"]["id"].to_s
          recover_payload = redis.get("#{get_redis}")
          if recover_payload.nil?
            return "Your build has not found pushed event, send a tested webhooked"
          else
            return "For build #{recover_payload}"
          end
          #elsif data[:object_attributes][:state] == 'reopened'
          #  url_2 =  "#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{data[:object_attributes][:source_project_id]}/"
          #  url_2 << "repository/branches/#{data[:object_attributes][:source_branch]}"
          #  url_2 << "?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}"
          #  request_project = http.get(url_2)
          #  gitlab_data = parse_payload(symbolize request_project.body)
          #  get_redis << gitlab_data["commit"]["id"].to_s
          #  recover_payload = redis.get("#{get_redis}")
          #  if recover_payload.nil?
          #    return "Your build has not found pushed event, send a tested webhooked"
          #  else
          #    return "For build #{recover_payload}"
          #  end
        else

          return "For build Desavaible"

        end

      rescue
        Lita.logger.info "NOCACHO"

      end






      def interpolate_message(key, data)
        t(key) % data
      end





    end

    Lita.register_handler(Gitlab2jenkinsGhp)
  end
end
