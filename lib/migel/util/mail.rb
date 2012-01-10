#!/usr/bin/env ruby
# encoding: utf-8
# Migel::Util::Mail -- migel -- 10.01.2012 -- mhatakeyama@ywesee.com

require 'rmail'
require 'net/smtp'
require 'migel/config'
require 'migel/util/smtp_tls'
require 'mail'
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
        mail = ::Mail.new
        mail.subject = subject
        mail.date = Time.now
        mail.mime_version = '1.0'

        # Text part
        text = ::Mail.new
        text.content_type('text/plain; charset=UTF-8')
        text.body = lines.join("\n")
        mail.parts.push text

        # File part
        if file
          attach = ::Mail.new
          attach.add_file(file)
          mail.parts.push attach
        end

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
