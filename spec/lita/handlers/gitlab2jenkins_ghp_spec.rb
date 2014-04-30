require 'spec_helper'

describe Lita::Handlers::Gitlab2jenkinsGhp, lita_handler: true do

  http_route_path =  '/lita/gitlab2jenkinsghp'

  it 'registers with Lita' do
    expect(Lita.handlers).to include(described_class)
  end

  let(:request) do
    request = double('Rack::Request')
    allow(request).to receive(:params).and_return(params)
    request
  end
  let(:response) { Rack::Response.new }
  let(:params) { {} }
  let(:id_project) { '7' }
  let(:commit_id) {'cfa9e9a8421e45407d03dc8d2e0ac0e80ea9dba1'}
  let(:redis_key_commit) {"commit:#{commit_id}"}
  let(:merge_request) { '82' }
  let(:to_route_gitlab) { 'gitlab' }
  let(:request_method_post) { 'POST' }
  let(:request_method_get) { 'GET' }
  let(:project_name_target) { 'api' }
  let(:redis_key_merge_request) {"mr:#{project_name_target}:#{merge_request}"}

  let(:to_route_jenkins) { 'jenkins' }
  let(:jenkins_id_project) { '7' }
  let(:redis_key_jenkins_job) { 'jenkins:api:130' }
  let(:project_name_params) { 'api' }
  let(:to_route_ci_status) { 'ci_status' }

  describe '#receive' do

    context 'Using POST endpoint for gitlab' do

      it "route gitlab push event POST #{http_route_path}/gitlab to :receive" do
        routes_http(:post, "#{http_route_path}/#{to_route_gitlab}").to(:receive)
      end

      context 'when is push event commit hook' do
        let(:push_event_commit_payload) { fixture_file('gitlab/push_event_commit') }
        before do
          allow(params).to receive(:[]).with('payload').and_return(push_event_commit_payload)
          allow(params).to receive(:[]).with('request_method').and_return(request_method_post)
          allow(params).to receive(:[]).with('to_route').and_return(to_route_gitlab)
          Lita::Handlers::Gitlab2jenkinsGhp.new(robot).receive(request, response)
        end
        it 'notifies what commit its stored' do
          expect(Lita.redis.redis.get("lita.test:handlers:gitlab2jenkins_ghp:#{redis_key_commit}")).to eq push_event_commit_payload
        end
      end

      context 'when is a open merge request hook' do
        let(:merge_request_event_open_payload) { fixture_file('gitlab/merge_request_event_open') }
        before do
          allow(params).to receive(:[]).with('payload').and_return(merge_request_event_open_payload)
          allow(params).to receive(:[]).with('request_method').and_return(request_method_post)
          allow(params).to receive(:[]).with('to_route').and_return(to_route_gitlab)
          allow(params).to receive(:[]).with('project_name_target').and_return(project_name_target)
          allow(params).to receive(:[]).with('project_source_id_commit').and_return(commit_id)
          Lita::Handlers::Gitlab2jenkinsGhp.new(robot).receive(request, response)
        end
        it 'notifies what merge request its stored' do
            expect(Lita.redis.redis.get("lita.test:handlers:gitlab2jenkins_ghp:#{redis_key_merge_request}")).to eq merge_request_event_open_payload
        end
      end

      context 'when is a reopened merge request hook' do
        let(:merge_request_event_reopened_payload) { fixture_file('gitlab/merge_request_event_reopened') }
        before do
          allow(params).to receive(:[]).with('payload').and_return(merge_request_event_reopened_payload)
          allow(params).to receive(:[]).with('request_method').and_return(request_method_post)
          allow(params).to receive(:[]).with('to_route').and_return(to_route_gitlab)
          allow(params).to receive(:[]).with('project_name_target').and_return(project_name_target)
          allow(params).to receive(:[]).with('project_source_id_commit').and_return(commit_id)
          Lita::Handlers::Gitlab2jenkinsGhp.new(robot).receive(request, response)
        end
        it 'notifies what merge request its stored' do
          expect(Lita.redis.redis.get("lita.test:handlers:gitlab2jenkins_ghp:#{redis_key_merge_request}")).to eq merge_request_event_reopened_payload
        end
      end

      context 'when is a closed merge request hook' do
        let(:merge_request_event_closed_payload) { fixture_file('gitlab/merge_request_event_closed') }
        before do
          allow(params).to receive(:[]).with('payload').and_return(merge_request_event_closed_payload)
          allow(params).to receive(:[]).with('request_method').and_return(request_method_post)
          allow(params).to receive(:[]).with('to_route').and_return(to_route_gitlab)
          allow(params).to receive(:[]).with('project_name_target').and_return(project_name_target)
          allow(params).to receive(:[]).with('project_source_id_commit').and_return(commit_id)
          Lita::Handlers::Gitlab2jenkinsGhp.new(robot).receive(request, response)
        end
        it 'notifies what merge request its stored' do
          expect(Lita.redis.redis.keys("lita.test:handlers:gitlab2jenkins_ghp:#{redis_key_merge_request}").size).to eq 0
        end
      end
    end

    context 'Using POST endpoint for jenkins' do
      it "route gitlab push event POST #{http_route_path}/jenkins to :receive" do
        routes_http(:post, "#{http_route_path}/#{to_route_jenkins}").to(:receive)
      end

      context 'when jenkins post status job when is STARTED' do
        let(:jenkins_started_payload) { fixture_file('jenkins/job_started') }
        before do
          allow(params).to receive(:[]).with('payload').and_return(jenkins_started_payload)
          allow(params).to receive(:[]).with('request_method').and_return(request_method_post)
          allow(params).to receive(:[]).with('to_route').and_return(to_route_jenkins)
          allow(params).to receive(:[]).with('id_project').and_return(jenkins_id_project)
          allow(params).to receive(:[]).with('project_name_params').and_return(project_name_params)
          Lita::Handlers::Gitlab2jenkinsGhp.new(robot).receive(request, response)
        end
        it 'notifies what merge request its stored' do
          expect(Lita.redis.redis.get("lita.test:handlers:gitlab2jenkins_ghp:#{redis_key_jenkins_job}")).to eq jenkins_started_payload
        end
      end

      context 'when jenkins post status job when is FINISHED' do
        let(:jenkins_finished_payload) { fixture_file('jenkins/job_finished') }
        before do
          allow(params).to receive(:[]).with('payload').and_return(jenkins_finished_payload)
          allow(params).to receive(:[]).with('request_method').and_return(request_method_post)
          allow(params).to receive(:[]).with('to_route').and_return(to_route_jenkins)
          allow(params).to receive(:[]).with('id_project').and_return(jenkins_id_project)
          allow(params).to receive(:[]).with('project_name_params').and_return(project_name_params)
          Lita::Handlers::Gitlab2jenkinsGhp.new(robot).receive(request, response)
        end
        it 'notifies what merge request its stored' do
          expect(Lita.redis.redis.get("lita.test:handlers:gitlab2jenkins_ghp:#{redis_key_jenkins_job}")).to eq jenkins_finished_payload
        end
      end
    end


    context 'Using GET endpoint from gitlab' do
      it "route gitlab fetch data of a GET #{http_route_path}/ci_status to :receive" do
        routes_http(:post, "#{http_route_path}/#{to_route_ci_status}").to(:receive)
      end
    end


  end

end
