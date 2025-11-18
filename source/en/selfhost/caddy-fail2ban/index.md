<!-- BEGIN ARISE ------------------------------
Title:: "Using Caddy along with Fail2Ban to harden your services"

Author:: "Jose Falanga"
Description:: "Step by step guide to harden your services"
Language:: "en"
Published Date:: "2025-11-18"
Modified Date:: "2022-11-18"
content_header:: "true"
rss_hide:: "false"
---- END ARISE \\ DO NOT MODIFY THIS LINE ---->
# Using Caddy along with Fail2Ban to harden your services

If you are looking for a guide on how to configure [caddy-fail2ban module](https://github.com/Javex/caddy-fail2ban), you are in the wrong place. This approach uses no extra modules, and requires both fail2ban and caddy to be installed on your host (no docker/container). You can use docker for everything else.

This doesn't mean you cannot use containers for this at all (_you will notice using volumes smartly can totally allow this workflow_), but I'm choosing this setup because it is more straightforward for newcomers, as we won't delve in docker details.

That said, let's start dissecting this.

## What's Caddy

Well, can't do justice to the absolute beast Caddy is, but you can go check their [Website](https://caddyserver.com/) and their [Docs](https://caddyserver.com/docs/). In short, I'm using Caddy as a reverse proxy and access point for all my self-hosted services. Caddy manages redirecting stuff to the appropiate containers, depending on what domain the request is entering from. This means that I can set `something.thergic.ar` regular `80` port to be forwarded to some internal docker port. It also magically manages SSL certificates through [Let's Encrypt](https://letsencrypt.org/), so it also redirects stuff through `443`, no extra setup needed. It's not that `certbot` is hard to use, but Caddy makes the whole thing trivial. It can also be set up to create wildcard certificates. It can do way more than that, and I'll probably expand on this later, but that's what I've got so far.

## What's Fail2Ban

Their own [github](https://github.com/fail2ban/fail2ban) readme starts with a pretty good definition: 

> Fail2Ban: ban hosts that cause multiple authentication errors

Just installing it protects you from SSH brute-forcing, and many other common threats. But here is the thing, it is amazingly flexible because it depends on monitoring logs. So you can introduce new configurations for everything that is being logged in your host.

## Connecting the dots

![](now-kiss.png)

Well, we can totally make those interact! Main idea is, Caddy logs stuff, Fail2Ban ingests those, and bans bots and crawlers. 

Caddy logs include the http code each service assigns to their response. So I had an idea for my first rule. Crawlers poll your routes and paths in attempts to grab exposed stuff, so they get a lot of 404s. Brute force attacks to login pages will end up in a lot of 403s, rate limiting is 429. You get the idea, bad-faith actors will trigger a lot of 4xx errors, within short time windows.  

## Implementation

### Caddy

#### Install

First, go and pick an [install method](https://caddyserver.com/docs/install). I'm using plain debian, so I went with the `apt` option:

```bash
sudo apt install caddy
sudo systemctl enable --now caddy
```

I will use the Caddyfile to achieve all my goals. I will not delve too deep into this, you can go to [Caddyfile docs](https://caddyserver.com/docs/caddyfile) for an in-depth explanation and examples of its structure and supported syntax and cases.

Your Caddyfile usually sits at `/etc/caddy/Caddyfile`. I like to create a symlink in the home dir for easy access:

```bash
sudo ln -s /etc/caddy/Caddyfile ~/
```

#### Setup

So we edit it:

```bash
sudo nano ~/Caddyfile
```

This is what mine looked like (actual domain names replaced):

```bash
subdomain.thergic.ar {
        reverse_proxy localhost:1234
}

this.isanother.domain {
        reverse_proxy localhost:2345
}

notallowed.access.com {
        respond 404
}
```

Just with that, Caddy is already redirecting stuff and managing SSL certs. Amazing, right? So, now  I'm going to introduce this block for all domains:

```bash
log {
	output file /var/log/caddy/access.log
	format console
}
```

The `format` option is important so Fail2Ban can properly parse this with the regex as a single line.

This also can be configured globally, but I wanted to make it case by case, so I can keep my rules flexible. Final Caddyfile looks like this:

```bash
subdomain.thergic.ar {
        reverse_proxy localhost:1234
        log {
                output file /var/log/caddy/access.log
                format console
        }
}

this.isanother.domain {
        reverse_proxy localhost:2345
        log {
                output file /var/log/caddy/access.log
                format console
        }
}

notallowed.access.com {
        respond 404
        log {
                output file /var/log/caddy/access.log
                format console
        }
}
```

Save it and reload the caddy service:

```bash
sudo systemctl restart caddy
```

On top of Caddy's magic, we now have access logs! This is how an actual line looks like:

```bash
2025/11/14 04:26:51.951	INFO	http.log.access.log1	handled request	{"request": {"remote_ip": "195.178.110.201", "remote_port": "40968", "client_ip": "195.178.110.201", "proto": "HTTP/1.1", "method": "GET", "host": "subdomain.thergic.ar", "uri": "/.env", "headers": {"Accept-Encoding": ["gzip, deflate"], "User-Agent": ["Python/3.10 aiohttp/3.13.1"], "Cookie": ["REDACTED"], "Accept": ["*/*"]}, "tls": {"resumed": false, "version": 772, "cipher_suite": 4865, "proto": "http/1.1", "server_name": "subdomain.thergic.ar"}}, "bytes_read": 0, "user_id": "", "duration": 0.010455752, "size": 11, "status": 404, "resp_headers": {"Content-Length": ["11"], "Cache-Control": ["max-age=0, private, must-revalidate, no-transform"], "Content-Type": ["text/plain;charset=utf-8"], "X-Content-Type-Options": ["nosniff"], "X-Frame-Options": ["SAMEORIGIN"], "Via": ["1.1 Caddy"], "Alt-Svc": ["h3=\":443\"; ma=2592000"], "Date": ["Fri, 14 Nov 2025 04:26:51 GMT"]}}
```

Look at that! This crawler is hunting for my server secrets! Note it's trying to access `/.env`, the user agent is Python (sucker didn't even try to spoof it). This is an actual attack an actual bot did to my server. 

And the magic sections are `"remote_ip": "195.178.110.201",` and `"status": 404`. This means we know _WHO_ this person is, and _WHAT_ the wrongdoing is. Let's configure Fail2Ban to put this sucker into bot jail.

![Time to Fail2Ban](bonk-jail.png)

### Fail2Ban

#### Install

```bash
sudo apt install fail2ban caddy
sudo systemctl enable --now fail2ban
```

That already enabled a lot of different protections for your server. One of the most useful is `sshd`. Don't get me wrong, you shouldn't expose your SSH to the open internet. If you do, then you should disable password access and only use ssh authorized keys. But if you are stubborn enough to not follow any of that advice, then fail2ban already got your back.

Wanna try it? Execute this:

```bash
watch sudo fail2ban-client status sshd
```

That will output something like this and update every 2 seconds:

```bash
Status for the jail: sshd
|- Filter
|  |- Currently failed:	0
|  |- Total failed:	0
|  `- File list:	/var/log/auth.log
`- Actions
   |- Currently banned:	0
   |- Total banned:	0
   `- Banned IP list:	
```

Now open another terminal, and fail to login with ssh. You will see the count going up in real time. Now stop doing that, you are going to get yourself banned! Fail2Ban will add an `iptables` rule and you will be out.

#### Setup

Well, as Minecraft is the sum of Mine and Craft, Fail2Ban needs Fails and Ban (rules) to work. Let's start with the fails. We are going to create a new filter:

```bash
sudo nano /etc/fail2ban/filter.d/caddy-400.conf
```

And inside we paste the following:

```bash
[Definition]
failregex = ^.*"remote_ip": "<HOST>".*"status": 4[0-9][0-9]
ignoreregex =
```

This regex will match anything in the range of 4xx. You can opt to only match some, but for me, every bad request is an offense. I'm not including 5xx here, as they only denote the service malfunctioning. If I detect in the future some bad-faith actor making my services crash on purpose, I can totally add another filter for that.

Now, let's create a jail for the bans:

```bash
sudo nano /etc/fail2ban/jail.d/caddy-400.conf
```

Contents example:

```bash
[caddy-400]
enabled = true
logpath = /var/log/caddy/access.log
maxretry = 10
findtime = 60
bantime = 36000
```

Explanation:
- `maxretry`: how many fails are allowed? Just 10
- `findtime`: how far in the past I need to look? 1 minute
- `bantime`: how much time the ban will last? 10 hours

So, if your python bot triggers 10 4xx errors across any of my services within a minute, you are officially in jail. You can adjust this to tighten or loosen the limits. The idea is to only capture bad-faith actors and not ban human users on accident, so you need to tune for false positives. It is hard for humans to make 10 offenses in 1 minute, usually bots do it, as they operate in fast bursts. If you want to also handle slow crawlers, you need to either increase the `findtime` or decrease the `maxretry`, or both.

Reload the service:

```bash
sudo systemctl restart fail2ban
```

You can check the jail status with:

```bash
sudo fail2ban-client status caddy-400
```

Outputs:

```bash
Status for the jail: caddy-400
|- Filter
|  |- Currently failed:	4
|  |- Total failed:	6
|  `- File list:	/var/log/caddy/access.log
`- Actions
   |- Currently banned:	0
   |- Total banned:	0
   `- Banned IP list:	
```

That's it!

## Monitoring

This can probably be improved. You could get email alerts when fail2ban acts if you like. I didn't configure that, so I'm using this to monitor bans manually after the fact:

```bash
sudo cat /var/log/fail2ban.log.1 | grep Ban
```

That outputs something like:

```bash
[date] fail2ban.actions        [708]: NOTICE  [caddy-400] Ban 195.178.110.201
[date] fail2ban.actions        [709]: NOTICE  [caddy-400] Ban 16.171.237.119
[date] fail2ban.actions        [709]: NOTICE  [caddy-400] Ban 13.214.183.227
[date] fail2ban.actions        [709]: NOTICE  [caddy-400] Ban 195.178.110.201
```

That's the actual output of my server. And if you are curious about how that happened, you can go to caddy logs and check one particular IP:

```bash
sudo cat /var/log/caddy/access.log | grep "195.178.110.201" > attack
```
## Success!

If you followed the steps above, your services are now hardened against a lot of common cases and you will not waste CPU, network or any resource that would compromise your services availability. Of course this doesn't magically solve all cases, and you can still harden your self-hosted stuff. It's a stepping stone in the right direction.
## Support

If you liked this article, please support these amazing projects:
- Support/contribute to [Fail2Ban](https://github.com/fail2ban/fail2ban)
- Become a [Caddy](https://caddyserver.com/sponsor) sponsor
- Donate to [Let's Encrypt](https://letsencrypt.org/donate/)