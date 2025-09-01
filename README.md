# Hatchify Messaging Service

## Features

- my preferred devex: mise, Taskfile, docker, .env/direnv, lefthook, and single-command entrypoints
- integration tests
- Elixir API service

## TODO

- [ ] rename service from `messaging` 🥱

## Usage

### Setup

[Install `mise`](https://mise.jdx.dev/getting-started.html) to manage system dependencies for the project. Be sure to activate mise in your shell.

Initialize and setup dependencies:

```sh
# Run twice on first try (first time installs deps)
task init
```

#### DNS

Replace `${DOMAIN}` in `.env` with the value of the local domain, such as `usehatch.arpa`.

<details>
<summary>Setup local DNS for ${DOMAIN} to point to 127.0.0.1.</summary>

##### dnsmasq

Install `dnsmasq`.

Ensure development DNS works by first editing `dnsmasq.conf`.

```sh
sudo vim $(brew --prefix)/etc/dnsmasq.conf
```

```conf
# /opt/homebrew/etc/dnsmasq.conf or /etc/dnsmasq.conf
address=/usehatch/127.0.0.1
resolv-file=/etc/resolver/arpa
port=53
```

Then, add the resolver:

```sh
mkdir -v /etc/resolver
sudo vim /etc/resolver/arpa
```

```sh
# /etc/resolver/arpa
nameserver 127.0.0.1
```

```sh
# Darwin
sudo brew services start dnsmasq
```

See also: https://gist.github.com/ogrrd/5831371

</details>

### Run

To run the containerized demo locally, clone the repository and start the containers locally.

```sh
task up
```

Navigate to http://usehatch.arpa

### Develop

```
task start
```
