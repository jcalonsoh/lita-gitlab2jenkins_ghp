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
        config.saved_request         = ''
      end

      http.post '/lita/gitlab2jenkinsghp', :domr

      http.post '/lita/gitlab2jenkinsghp_mr_status', :domr_change_status

      def domr(request, response)
        json_body = extract_json_from_request(request)
        Lita.logger.info("Payload: #{json_body}")
        data = symbolize parse_payload(json_body)
        message = format_message(data, json_body)
        room = Lita.config.handlers.gitlab2jenkins_ghp.room
        target = Source.new(room: room)
        robot.send_message(target, message)
      end

      def domr_change_status(request, response)
        json_body = extract_json_from_request(request)
        Lita.logger.info("Payload: #{json_body}")
        data = symbolize parse_payload(json_body)
        message = format_message_mr(data, json_body)
        room = Lita.config.handlers.gitlab2jenkins_ghp.room
        target = Source.new(room: room)
        robot.send_message(target, message)
      rescue Exception => e
        Lita.logger.info "Doh something went wrong #{e.inspect}"
        return ""
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
        return obj.reduce({}) { |memo, (k, v)| memo[k.to_sym] =  symbolize(v); memo } if obj.is_a? Hash
        return obj.reduce([]) { |memo, v    | memo           << symbolize(v); memo } if obj.is_a? Array
        obj
      end

      def format_message(data, json)
        if data.key? :before
          build_branch_hook(data, json)
        elsif data.key? :object_kind
          build_merge_hook(data, json)
        else
          return ""
        end
      end

      def build_branch_hook(data, json)
        data[:link] = "<#{data[:repository][:homepage]}|#{data[:repository][:name]}>"
        redis.set(data[:commits][0][:id], json.to_s)
        "Commit Stored: #{data[:commits][0][:id]}"
      end

      def gitlab_rescue_commit(project_id, branch)
        http.get("#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{project_id}/repository/branches/#{branch}?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}")
      end

      def git_lab_data(project_id, branch)
        parse_payload((((gitlab_rescue_commit(project_id, branch)).to_hash)[:body]))
      end

      def gitlab_redis_get(id)
        redis.get(git_lab_data(data[:object_attributes][:source_project_id], data[:object_attributes][:source_branch])['commit']['id'])
        return
      end

      def jenkins_hook_ghp(json)
        http.post do |req|
          req.url Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins
          req.headers['Content-Type'] = 'application/json'
          req.body = json
        end
      rescue => e
        Lita.logger.info "URL #{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins}"
      end

      def build_merge_hook(data, json)
        if ['reopened', 'opened'].include? data[:object_attributes][:state]
          Lita.logger.info "It's a merge request"
          payload_rescue = redis.get(git_lab_data(data[:object_attributes][:source_project_id], data[:object_attributes][:source_branch])['commit']['id'])
          if (payload_rescue).size > 0
            Lita.logger.info "Merge request found"
            jenkins_hook_ghp(payload_rescue).inspect
          end
        end
      rescue Exception => e
        Lita.logger.info "Doh something went wrong #{e.inspect}"
        return ""
      end

      def format_message_mr(data, json)
        puts data
        puts json
      end





    end

    Lita.register_handler(Gitlab2jenkinsGhp)
  end
end
