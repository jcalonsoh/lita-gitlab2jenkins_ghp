# lita-gitlab2jenkins_ghp

[![Build Status](https://travis-ci.org/jcalonsoh/lita-gitlab2jenkins_ghp.svg)](https://travis-ci.org/jcalonsoh/lita-gitlab2jenkins_ghp)
[![Code Climate](https://codeclimate.com/github/jcalonsoh/lita-gitlab2jenkins_ghp.png)](https://codeclimate.com/github/jcalonsoh/lita-gitlab2jenkins_ghp)
[![Coverage Status](https://coveralls.io/repos/jcalonsoh/lita-gitlab2jenkins_ghp/badge.png)](https://coveralls.io/r/jcalonsoh/lita-gitlab2jenkins_ghp)

**lita-fitlab2jenkins_ghp** is a [Lita](https://github.com/jimmycuadra/lita) that uses [GitLab](https://www.gitlab.com/gitlab-ce/)
webhooks and ci-status to be build with [Jenkins](http://jenkins-ci.org/).


## Installation

Add lita-gitlab2jenkins_ghp to your Lita instance's Gemfile:

``` ruby
gem "lita-gitlab2jenkins_ghp"
```

## Configuration

### REQUERIMENTS:

You will need to install on Jenkins the next plugins =>

[Gitlab Hook Plugin 1.0.0](https://wiki.jenkins-ci.org/display/JENKINS/Gitlab+Hook+Plugin),
[Embeddable Build Status 1.4](https://wiki.jenkins-ci.org/display/JENKINS/Embeddable+Build+Status+Plugin),
[Notification Plugin 1.5](https://wiki.jenkins-ci.org/display/JENKINS/Notification+Plugin)

### Example usage YML

``` ruby
Lita.configure do |config|
  config.handlers.gitlab2jenkins_ghp.room                 = '#error_channel'
  config.handlers.gitlab2jenkins_ghp.url_gitlab           = 'http://gitlab.example.com'
  config.handlers.gitlab2jenkins_ghp.url_jenkins          = 'http://jenkins.example.com'
  config.handlers.gitlab2jenkins_ghp.url_jenkins_hook     = '/gitlab/build_now'
  config.handlers.gitlab2jenkins_ghp.url_jenkins_img      = '/buildStatus/icon?job='
  config.handlers.gitlab2jenkins_ghp.url_jenkins_icon     = '/static/843013a3/images/jenkins.png'
  config.handlers.gitlab2jenkins_ghp.private_token_gitlab = 'some_gitlab_token_from_admin_user'
  config.redis.host                                       = 'redis.example.com'
end
```

For more understanding please read [wiki](https://github.com/jcalonsoh/lita-gitlab2jenkins_ghp/wiki)

## License

[MIT](http://opensource.org/licenses/MIT)
