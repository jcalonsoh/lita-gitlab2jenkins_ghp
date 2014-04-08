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

      def gitlab_rescue_commit(project_id, branch)
        http.get("#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{project_id}/repository/branches/#{branch}?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}")
      rescue
        Lita.logger.info "#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{project_id}/repository/branches/#{branch}?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}"
        Lita.logger.info "gitlab_rescue_commit"
      end

      def get_commit_from_redis(id)
        redis.get(id)
        puts redis.get(id)
      rescue
        Lita.logger.info "get_commit_from_redis"
      end

      def git_lab_data(project_id, branch)
        parse_payload((((gitlab_rescue_commit(project_id, branch)).to_hash)[:body]))
      end

      def build_merge_message(data)
        if (data[:object_attributes][:state].to_s).include?('reopened', 'opened')
          recover_payload << redis.get(git_lab_data(data[:object_attributes][:source_project_id], data[:object_attributes][:source_branch])['commit']['id']).nil?
          return "For build #{recover_payload}"
        else
          Lita.logger.info "build_merge_sms #{data.inspect}"
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
