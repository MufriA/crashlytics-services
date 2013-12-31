=begin

Create bitbucket issues for new crashes.

User inputs are password and project url.
User name and Project name will parsed from project url.

project url is in format https://bitbucket.org/user_name/project_name

Ref API : https://confluence.atlassian.com/display/BITBUCKET/issues+Resource#issuesResource-POSTanewissue
API Test : http://restbrowser.bitbucket.org/

=end

class Service::Bitbucket < Service::Base

    title "Bitbucket"

    string :project_url, :placeholder => "https://bitbucket.org/user_name/project_name",
         :label => 'URL to your Bitbucket project: <br />' \
                   'This should be your URL after you select your repository after login'
    password :password, :placeholder => 'password',
         :label => 'Your Bitbucket password:'

    page "Repository", [ :project_url ]
    page "Login Information", [ :password ]

    def receive_verification(config, _)
        parsed = parse_url config[:project_url]
        http.ssl[:verify] = true
        http.basic_auth parsed[:user_name], config[:password]

        resp = http_get get_url(parsed)

        if resp.status == 200
            [true, "Successfully verified Bitbucket settings"]
        else
            log "HTTP Error: status code: #{ resp.status }, body: #{ resp.body }"
            [false, "Oops! Please check your settings again."]
        end

        rescue Exception => e
        log "Rescued a verification error in bitbucket: (url=#{config[:project_url]}) #{e}"
        [false, "Oops! Is your repository url correct?"]

     end


    def receive_issue_impact_change(config, payload)
        parsed = parse_url config[:project_url]
        http.ssl[:verify] = true
        http.basic_auth parsed[:user_name], config[:password]

        users_text = ""
        crashes_text = ""

        if payload[:impacted_devices_count] == 1
          users_text = "This issue is affecting at least 1 user who has crashed "
        else
          users_text = "This issue is affecting at least #{ payload[:impacted_devices_count] } users who have crashed "
        end

        if payload[:crashes_count] == 1
          crashes_text = "at least 1 time.\n\n"
        else
          "at least #{ payload[:crashes_count] } times.\n\n"
        end

        issue_description = "Crashlytics detected a new issue.\n" + \
                     "#{ payload[:title] } in #{ payload[:method] }\n\n" + \
                     users_text + \
                     crashes_text + \
                     "More information: #{ payload[:url] }"

        post_body = {
                            :kind => 'bug',
                            :title => payload[:title] + ' [Crashlytics]',
                            :description => issue_description
                    }

        puts post_body
        resp = http_post get_url(parsed) do |req|
        req.body = post_body

        #end

        if resp.status != 200
          raise "Bitbucket issue creation failed: #{ resp[:status] }, body: #{ resp.body }"
        end

        { :bitbucket_issue_id => JSON.parse(resp.body)['local_id'] }

        rescue Exception => e
            puts "Bitbucket issue creation failed: (url=#{config[:project_url]}) #{e}"
      end


    def parse_url(project_url)
        splittedArray = project_url.split('//').last.split('/')
        if splittedArray.length == 3 && splittedArray.first == 'bitbucket.org'
             result = { :user_name => splittedArray[1],
                        :project_name => splittedArray[2]
                      }
            result
        end
    end

    def get_url(parsed)
        url_prefix = 'https://bitbucket.org/api/1.0/repositories'
        url = "#{url_prefix}/#{parsed[:user_name]}/#{parsed[:project_name]}/issues/"
    end

end
