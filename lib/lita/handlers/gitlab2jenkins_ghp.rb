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

      http.post '/lita/gitlab2jenkinsghp/*to_route', :receive

      http.get '/lita/gitlab2jenkinsghp/*to_route/*id_project/builds/*sha_commit', :receive

      def receive(request, response)
        routing_to = request.params['to_route'] || request.env['router.params'][:to_route][0].to_s
        routing_to_request_method = request.params['request_method'] || request.request_method
        json_body = request.params['payload'] || extract_json_from_request(request)
        data = symbolize parse_payload(json_body)
        if data.key? :object_attributes
          project_name_target = request.params['project_name_target'] || git_lab_data_project_info(data[:object_attributes][:target_project_id])['name']
          project_source_id_commit = request.params['project_source_id_commit'] || git_lab_data_branch_info(data[:object_attributes][:source_project_id], data[:object_attributes][:source_branch])['commit']['id']
        else
          project_name_target = ''
          project_source_id_commit = ''
        end
        if routing_to_request_method =='POST'
          if routing_to == 'gitlab'       #receive hook from gitlab to report commits and merge request event
            do_mr(json_body, data, project_name_target, project_source_id_commit)
          elsif routing_to == 'jenkins'                                           #receive hook from jenkins to report job status build
            do_mr_change_status(request, response, json_body, data)
          end
        elsif routing_to_request_method =='GET'
          if routing_to == 'ci_status'
            if request.env['router.params'][:sha_commit][0].nil? false
              do_ci_change_status(request, response)
            else
              do_img_jenkins(request, response)
            end
          end
        end
        # robot.send_message(target, message)
      rescue Exception => e
        Lita.logger.error "Could not receive: #{e.inspect}"
      end

      def do_mr_change_status(request, response, json_body, data)
        id_project = request.params['id_project'].to_s
        Lita.logger.info "Jenkins Proyect: #{id_project}"
        Lita.logger.info("Payload: #{json_body}")
        ci_status_setter(data, json_body, id_project)

      rescue Exception => e
        Lita.logger.error "Could not domr_change_status: #{e.inspect}"
      end

      def do_ci_change_status(request, response)
        Lita.logger.info "GitLab CI Project ID: #{request.env['router.params'][:id_project]}"
        Lita.logger.info "GitLab CI Commit SHA: #{request.env['router.params'][:sha_commit]}"
        Lita.logger.info "GitLab CI Token: #{request.params['token']}"
        message = format_message_ci(request.env['router.params'][:id_project][0], request.env['router.params'][:sha_commit][0])
        room = Lita.config.handlers.gitlab2jenkins_ghp.room
        target = Source.new(room: room)
        if message.to_s != 'true'
          response['status'] = message
          Lita.logger.info "CI Final Status: #{message.to_s}"
        end
      rescue Exception => e
        Lita.logger.error "Could not domr_change_status: #{e.inspect}"
      end

      def do_img_jenkins(request, response)
        project_name = git_lab_data_project_info(request.env['router.params'][:id_project][0])['name']

        gkeys = @redis.keys("jenkins:#{project_name}:*")
        gkeys.each do |key|
          json_off = redis.get(key)
          jdata = symbolize parse_payload(json_off)
          job = jdata[:name]
          code_climate(job, response)
        end

        if gkeys.empty?
          nocode_climate(response)
        end

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

      def nocode_climate(response)
        url = "#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins.to_s}"<<"#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins_icon.to_s}"
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

      def do_mr(json_body, data, project_name_target, project_source_id_commit)
        if data.key? :before
          build_branch_hook(json_body, data)
        elsif data.key? :object_kind
          build_merge_hook(json_body, data, project_name_target, project_source_id_commit)
        end

      rescue => e
        Lita.logger.error "Could not format message: #{e.inspect}"
      end

      def build_branch_hook(json, data)
        redis.set("commit:#{data[:commits][0][:id]}", json.to_s)
        return "Commit Stored: #{data[:commits][0][:id]}"
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
        url = "#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins}" << "#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins_hook}"
        http.post do |req|
          req.url url
          req.headers['Content-Type'] = 'application/json'
          req.body = json
        end

        Lita.logger.info "Sending data to Jenkins: #{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins}#{Lita.config.handlers.gitlab2jenkins_ghp.url_jenkins_hook}"
        Lita.logger.info "With JSON: #{json}"

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

      def build_merge_hook(json, data, project_name_target, project_source_id_commit)
        redis.set("mr:#{project_name_target}:#{data[:object_attributes][:id]}", json.to_s)
        if ['reopened', 'opened'].include? data[:object_attributes][:state]
          Lita.logger.info "It's a merge request"
          payload_rescue = redis.get("commit:#{project_source_id_commit}")
          if (payload_rescue).size > 0
            Lita.logger.info "Merge request found"
            jenkins_hook_ghp(payload_rescue)
            "Merge Request found to play #{payload_rescue}"
          else
            "No commit found"
          end
        else
          redis.del("mr:#{project_name_target}:#{data[:object_attributes][:id]}")
          gkeys = @redis.keys("jenkins:#{project_name_target}:*")
          gkeys.each do |key|
            Lita.logger.info "Jenkins Key for Delete: #{key}"
            json_off = redis.get(key)
            jdata = symbolize parse_payload(json_off)
            Lita.logger.info "Branch found for delete: #{jdata[:build][:parameters][:ANY_BRANCH_PATTERN]}"
            redis.del(key) if data[:object_attributes][:source_branch] == jdata[:build][:parameters][:ANY_BRANCH_PATTERN]
          end
          "Merge request for delete"
        end

      rescue Exception => e
        Lita.logger.error "Could not make Build Merge Reques #{e.inspect}"
      end

      def key_value_source_project_finder_mr(source_project, project_name)
        gkeys = @redis.keys("mr:#{project_name}:*")
        gkeys.each do |key|
          json = redis.get(key)
          data = symbolize parse_payload(json)
          source_project_id = data[:object_attributes][:source_project_id] if data[:object_attributes][:source_branch] == source_project
        end

      rescue Exception => e
        Lita.logger.error "Could not key_value_source_project_finder_mr #{e.inspect}"
      end

      def ci_status_setter(data, json, id)
        project_name = git_lab_data_project_info(id)['name']
        source_project_id = key_value_source_project_finder_mr(data[:build][:parameters]['ANY_BRANCH_PATTERN'],project_name)
        redis.set("jenkins:#{project_name}:#{data[:build][:number]}", json)

      rescue Exception => e
        Lita.logger.error "Could not format_message_mr #{e.inspect}"
      end

      def key_value_build_finder_jenkins(source_project, project_name)
        gkeys = @redis.keys("jenkins:#{project_name}:*")
        Lita.logger.info "Jenkins Status found key: #{gkeys.inspect}"
        gkeys.each do |key|
          Lita.logger.info "Jenkins Status key #{key}"
          json = redis.get(key)
          data = symbolize parse_payload(json)
          Lita.logger.info "Branch found #{data[:build][:parameters][:ANY_BRANCH_PATTERN]}"
          if data[:build][:phase] == 'FINISHED'
            if data[:build][:parameters][:ANY_BRANCH_PATTERN] == source_project
              if data[:build][:status] == 'FAILURE'
                return 'failed'
              else
                return 'success'
              end
              Lita.logger.info "Status: #{data[:build][:status]}"
            end
          elsif data[:build][:phase] == 'STARTED'
            return 'running' if data[:build][:parameters][:ANY_BRANCH_PATTERN] == source_project
          else
            return 'pending'
          end
        end

        return 'error'

      rescue Exception => e
        Lita.logger.error "Could not key_value_build_finder_jenkins #{e.inspect}"
      end


      def key_value_commit_source_project_finder_jenkins(commit, project_name)
        gkeys = @redis.keys("mr:#{project_name}:*")
        Lita.logger.info "Loking Array data for: #{gkeys.inspect}"
        gkeys.each do |key|
          Lita.logger.info "Loking data in #{key.inspect}"
          json = redis.get(key)
          data = symbolize parse_payload(json)
          json_from_gitlab = get_commit_from_gitlab_source_project(data[:object_attributes][:source_project_id],data[:object_attributes][:source_branch]).body
          data_gitlab = symbolize parse_payload(json_from_gitlab)
          return data_gitlab[:name] if data_gitlab[:commit][:id] == commit
        end

      rescue Exception => e
        Lita.logger.error "Could not key_value_commit_source_project_finder_jenkins #{e.inspect}"
      end

      def get_commit_from_gitlab_source_project(id, branch)
        url = http.get("#{Lita.config.handlers.gitlab2jenkins_ghp.url_gitlab}/api/v3/projects/#{id}/repository/branches/#{branch}?private_token=#{Lita.config.handlers.gitlab2jenkins_ghp.private_token_gitlab}")
      rescue => e
        Lita.logger.error "Could not rescue GitLab commit: #{e.inspect}"
      end

      def format_message_ci(id, commit)
        project_name = git_lab_data_project_info(id)['name']
        source_project = key_value_commit_source_project_finder_jenkins(commit, project_name)
        Lita.logger.info "Looking Status CI: #{source_project}"
        return key_value_build_finder_jenkins(source_project, project_name)

      rescue Exception => e
        Lita.logger.error "Could not format_message_ci #{e.inspect}"
      end


    end

    Lita.register_handler(Gitlab2jenkinsGhp)
  end
end
