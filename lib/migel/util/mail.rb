#!/usr/bin/env ruby
# encoding: utf-8
# Migel::Util::Mail -- migel -- 19.09.2011 -- mhatakeyama@ywesee.com

require 'rmail'
require 'net/smtp'
require 'migel/config'
require 'migel/util/smtp_tls'
require 'tmail'
require 'base64'

module Migel
  module Util
    module Mail
      def Mail.notify_admins(subject, lines)
        config = Migel.config
        recipients = config.admins
        mpart = RMail::Message.new
        header = mpart.header
        header.to = recipients
        header.from = config.mail_from
        header.subject = subject
        header.date = Time.now
        header.add('Content-Type', 'text/plain', nil, 
                   'charset' => config.mail_charset)
        mpart.body = lines.join("\n")
        sendmail(mpart, config.smtp_user, recipients)
      end
      def Mail.notify_admins_attached(subject, lines, file)
        config = Migel.config
        recipients = config.admins

        # Main part
        mail = TMail::Mail.new
        mail.subject = subject
        mail.date = Time.now
        mail.mime_version = '1.0'

        # Text part
        text = TMail::Mail.new
        text.set_content_type('text', 'plain', 'charset'=>'UTF-8')
        text.body = lines.join("\n")
        mail.parts.push text

        # File part
        attach = TMail::Mail.new
        attach.body = Base64.encode64 File.read(file)
#        attach.set_content_type('image','jpg','name' => file)
        attach.set_content_disposition('attachment', 'filename' => File.basename(file))
        attach.transfer_encoding = 'base64'
        mail.parts.push attach

        sendmail(mail.encoded, config.smtp_user, recipients)
      end
      def Mail.sendmail(mpart, from, recipients)
        config = Migel.config
        Net::SMTP.start(config.smtp_server, config.smtp_port,
                        config.smtp_domain, config.smtp_user, config.smtp_pass,
                        config.smtp_authtype) do |smtp|
          recipients.each { |recipient|
            smtp.sendmail(mpart.to_s, from, recipient)
          }
        end
      end
    end
  end
end
