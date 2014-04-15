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

      http.post '/lita/gitlab2jenkinsghp', :do_mr

      http.post '/lita/gitlab2jenkinsghp_mr_status', :do_mr_change_status

      http.get '/lita/gitlab2jenkinsghp_ci_status/*id_project/builds/*sha_commit', :do_ci_change_status

      http.get '/lita/gitlab2jenkinsghp_ci_status/*id_project', :do_img_jenkins

      def do_mr(request, response)
        json_body = extract_json_from_request(request)
        Lita.logger.info("Payload: #{json_body}")
        data = symbolize parse_payload(json_body)
        message = format_message(data, json_body)
        room = Lita.config.handlers.gitlab2jenkins_ghp.room
        target = Source.new(room: room)
        if message.to_s != 'true'
          robot.send_message(target, message)
        end

      rescue Exception => e
        Lita.logger.error "Could not domr: #{e.inspect}"
      end

      def do_mr_change_status(request, response)
        json_body = extract_json_from_request(request)
        id_project = request.params['id_project'].to_s
        Lita.logger.info "Jenkins Proyect: #{id_project}"
        Lita.logger.info("Payload: #{json_body}")
        data = symbolize parse_payload(json_body)
        message = format_message_mr(data, json_body, id_project)
        room = Lita.config.handlers.gitlab2jenkins_ghp.room
        target = Source.new(room: room)
        if message.to_s != 'true'
          robot.send_message(target, message)
        end

      rescue Exception => e
        Lita.logger.error "Could not domr_change_status: #{e.inspect}"
      end

      def do_ci_change_status(request, response)
        json_body = extract_json_from_request(request)
        Lita.logger.info "GitLab CI Project ID: #{request.env['router.params'][:id_project]}"
        Lita.logger.info "GitLab CI Commit SHA: #{request.env['router.params'][:sha_commit]}"
        Lita.logger.info "GitLab CI Token: #{request.params['token']}"
        Lita.logger.info("Payload: #{json_body}")
        #ci_opts = {
        #    :status => 'success'
        #}
        response['status'] = 'failed'
        data = symbolize parse_payload(json_body)
        message = format_message_ci(data, json_body)
        room = Lita.config.handlers.gitlab2jenkins_ghp.room
        target = Source.new(room: room)
        if message.to_s != 'true'
          robot.send_message(target, message)
        end

      rescue Exception => e
        Lita.logger.error "Could not domr_change_status: #{e.inspect}"
      end

      def do_img_jenkins(request, response)
        project_name = git_lab_data_project_info(request.env['router.params'][:id_project][0])['name']

        gkeys = @redis.keys("mr:#{project_name}:*")

        code_climate('QA-API', response)

      rescue Exception => e
        Lita.logger.error "Could not do_img_jenkins: #{e.inspect}"
      end

      private

      def code_climate(job, response)
        url = "#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins.to_s}"<<"#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins_img.to_s}"<<"#{job}"
        uri = URI(url)
        res = Net::HTTP.get_response(uri)

        if res.is_a?(Net::HTTPSuccess)
          response.body << res.body
          response['Content-Type'] = res['Content-Type']
        end

        Lita.logger.info "Sending Jenkins to Gitlab Code Climate #{url}"

      rescue Exception => e
        Lita.logger.error "Could not do_img_jenkins: #{e.inspect}"
      end

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
        end

      rescue => e
        Lita.logger.error "Could not format message: #{e.inspect}"
      end

      def build_branch_hook(data, json)
        data[:link] = "<#{data[:repository][:homepage]}|#{data[:repository][:name]}>"
        redis.set("commit:#{data[:commits][0][:id]}", json.to_s)
        "Commit Stored: #{data[:commits][0][:id]}"
      end

      def gitlab_rescue_commit(project_id, branch)
        http.get("#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{project_id}/repository/branches/#{branch}?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}")

      rescue => e
        Lita.logger.error "Could not rescue GitLab commit: #{e.inspect}"
      end

      def git_lab_data_branch_info(project_id, branch)
        parse_payload((((gitlab_rescue_commit(project_id, branch)).to_hash)[:body]))
      end

      def jenkins_hook_ghp(json)
        http.post do |req|
          req.url '#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins}#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins_hook}'
          req.headers['Content-Type'] = 'application/json'
          req.body = json
        end

      rescue => e
        Lita.logger.error "Could not make hook to jenkins: #{e.inspect}"
      end

      def rescue_gitlab_project_name (id)
        url = http.get("#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{id}?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}")
      rescue => e
        Lita.logger.error "Could not rescue GitLab commit: #{e.inspect}"
      end

      def git_lab_data_project_info(id)
        parse_payload((((rescue_gitlab_project_name(id)).to_hash)[:body]))
      end

      def build_merge_hook(data, json)
        redis.set("mr:#{git_lab_data_project_info(data[:object_attributes][:target_project_id])['name']}:#{data[:object_attributes][:id]}", json.to_s)
        "Saved Merge Request: #{data[:object_attributes][:id]}"
        if ['reopened', 'opened'].include? data[:object_attributes][:state]
          Lita.logger.info "It's a merge request"
          payload_rescue = redis.get("commit:#{git_lab_data_branch_info(data[:object_attributes][:source_project_id], data[:object_attributes][:source_branch])['commit']['id']}")
          if (payload_rescue).size > 0
            Lita.logger.info "Merge request found"
            jenkins_hook_ghp(payload_rescue).response.status
          end
        end

      rescue Exception => e
        Lita.logger.error "Could not make Build Merge Reques #{e.inspect}"
      end

      def key_value_source_project_finder(source_project, project_name)
        gkeys = @redis.keys("mr:#{project_name}:*")
        gkeys.each do |key|
          json = redis.get(gkeys[keys])
          data = symbolize parse_payload(json)
          source_project_id = data[:object_attributes][:source_project_id] if data[:object_attributes][:source_branch] == source_project
        end

        return source_project_id

      rescue Exception => e
        Lita.logger.error "Could not key_value_source_project_finder #{e.inspect}"
      end

      def format_message_mr(data, json, id)
        project_name = git_lab_data_project_info(id)['name']
        source_project_id = key_value_source_project_finder(data[:build][:parameters]['ANY_BRANCH_PATTERN'],project_name)
        redis.set("jenkins:#{project_name}:#{data[:build][:number]}", json)
        puts data
        puts json
      end

      def format_message_ci(data, json)
        puts data
        puts json
      end



    end

    Lita.register_handler(Gitlab2jenkinsGhp)
  end
end
