# Hatchify Messaging Service

The [project specifications](https://github.com/Hatch1fy/messaging-service) from [Hatch](usehatch.ai) are found in [PROJECT.md](PROJECT.md).

## Submission Results

The company did not proceed with the technical interview after my submission. Let's examine why.

### Feedback

Here is the feedback from the team shared by the company recruiter:

> Brett,
>
> A couple comments from the team were:
>
> he also didn't provide any context on the his decision to part with norms.
>
> There are a lot of redundancies via code comments and the code itself, calls to deprecated library functions, nested conditional logic, no clear separation of concerns, hand rolled GenServers, and again poor documentation.

This feedback may be based on a superficial review or different coding standards preferences rather than actual code analysis.

### Analysis

- This feedback appears to be largely inaccurate.
- There are some oversights that are worth correcting.
- The team demonstrates some non-idiomatic familiarity with Elixir.

#### Standards

I couldn't locate any "calls to deprecated library functions". I do have [1 nested case statement](lib/messaging/messages.ex#L121) inside an if statement. A couple files do contain unnecessary inline code comments and are obviously a side-effect of AI. I left them in some less interesting parts of the codebase, and I should have cleaned these up.

It's valid to say I'm missing API documentation. Despite the [project](PROJECT.md) specifications not mentioning this expectation, I should still have documented the few endpoints in the [router](lib/messaging_web/router.ex). I had expected the company would use the commands they created in their [Makefile](Makefile).

I also noticed after submitting that one of the tests in [test.sh](bin/test.sh) expects an integer ID of 1 for conversations, whereas out of habit I used UXIDs. This isn't acceptable and I should have caught it right away. I added much more in-depth and interesting tests in [test-more.sh](bin/test-more.sh) and ended up focusing on those (with a few edge cases failing as an opportunity to discuss with the team).

Most the feedback is simply specific to a team's own coding standards which are unknown to me. I also probably made some mistakes working so quickly, and I take responsibility for that. Where I work, we don't test for opinionated coding norms in interviews because it doesn't make for very interesting discussion.

#### GenServers

The most fascinating feedback to me is this:

> hand rolled GenServers

This refers to [outbox_processor.ex](lib/messaging/outbox_processor.ex) which processes messages in batches. I had guessed from the [project](PROJECT.md) requirements that the company would want to see a transactional outbox pattern for handling messaging side-effects, but I never would have guessed that a GenServer would be inappropriate to an Elixir team. GenServers are the Elixir Way™. I suppose an alternative is to use Oban or Broadway, but I don't agree with that approach. Broadway is an abstraction with GenStage, which is an implementation of GenServer, to work with external queues.

#### Design

Perhaps the team didn't like seeing Bandit instead of Phoenix, but I thought it was a fun exercise for such a small service. My `Messaging` and `MessagingWeb` constitutes a "typical separation of concerns" practical to both libraries along with other separations such as Controllers, Conversations, Messages, Integrations, and RateLimit. The test `exs` files next to their test targets is probably too opinionated to have implemented in this project.

#### Conclusion

The hiring manager confessed to me that "work-life balance" is a "four letter word to the CEO". This is a red flag to me, so I knew I was not a good fit, but I did want interviewing practice.

## Features

- my preferred devex: mise, Taskfile, docker, .env/direnv, lefthook, and single-command entrypoints
- integration tests
- Elixir API service
- List conversations by addresses
- Send message to provider
- Handle webook from messaging provider

## TODO

- [ ] rename service from `messaging` 🥱
- [ ] normalize participants

## Usage

### Setup

#### Make

```
make setup
```

```
make run
```

```
make test
```

#### Task & Docker

[Install `mise`](https://mise.jdx.dev/getting-started.html) to manage system dependencies for the project. Be sure to activate mise in your shell.

Initialize and setup dependencies:

```sh
# Run twice on first try (first time installs deps)
task init
```

##### DNS

Replace `${DOMAIN}` in `.env` with the value of the local domain, such as `usehatch.arpa`.

<details>
<summary>Setup local DNS for ${DOMAIN} to point to 127.0.0.1.</summary>

###### dnsmasq

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
