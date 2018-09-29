# dehydration-pdns-hook

Dehydration hook for DNS-01 challenge using PowerDNS API

The script runs only if challenge type is set to dns-01. It handles two
commands: `deploy_challenge`, and `clean_challenge`.

Both commands work similarly: they both receive all parameters at once,
search their domains in PowerDNS API, and sets (`deploy_challenge`) / removes
(`clean_challenge`) TXT records in zones managed by the server.

## Usage

- add `dns01.sh` to hooks (see
  [examples](https://github.com/lukas2511/dehydrated/wiki/Example:-Using-multiple-hooks))
- set `CHALLENGETYPE=dns-01` and `HOOK_CHAIN=yes` to either the main, or
  a domain-specific configuration
- consul-specific:
  - export `CONSUL_HTTP_TOKEN`, and, optionally `CONSUL_HTTP_ADDR`
    variables in dehydration`s config (see variable settings above).
    Don't forget to export these variables.
  - set `pdns/api_key` and `pdns/api_ip` in the consul kv store
- static setting:
  - export `API_URL` and `API_KEY` variables in dehydration's config
    (see variable settings above). Don't forget to export these
    variables.

## Contributing

1. Fork it
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create new Pull Request
