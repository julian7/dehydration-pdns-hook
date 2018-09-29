#!/usr/bin/env bash

declare -A domains
declare -A zones

[[ "${CHALLENGETYPE:-http-01}" != "dns-01" ]] && exit 0

main_func() {
    HANDLER="$1"
    shift
    case "$HANDLER" in
    deploy_challenge|clean_challenge)
        cmd "$HANDLER" "$@"
        ;;
    esac
}

discover() {
    [[ -n "${API_URL}" ]] && return
    API_IP=$(consul kv get pdns/api_ip)
    API_KEY=$(consul kv get pdns/api_key)
    API_URL="http://${API_IP}:8081"
}

pdns_call() {
    local method="$1" endpoint="$2" data="$3" error=false
    [[ -z "$API_IP" ]] && discover
    if [[ "${endpoint:0:1}" != "/" ]]; then
        : ${PDNS_PFX:=$(pdns_call GET /api | jq_filter url)}
        endpoint="$PDNS_PFX/$endpoint"
    fi
    if ! res="$(curl -sSfL --stderr - -X $method -H "X-Api-Key: $API_KEY" --data "${data}" "${API_URL}${endpoint}")"; then
        error=true
    fi
    if [[ "$res" = *"\"error\""* || "$error" == "true" ]]; then
        echo "API error: $res"
        echo "data: $data"
        exit 1
    fi
    echo "$res"
}

jq_filter() {
    jq -r ".[].$1"
}

collect_zones() {
    local server zone
    [[ "$zones_collected" == "true" ]] && return
    : ${PDNS_SERVERS:=$(pdns_call GET servers "" | jq_filter id)}
    for server in $PDNS_SERVERS; do
        while read zone; do
            zones[$zone]="$server"
        done < <(pdns_call GET servers/"${server}"/zones "" | jq_filter id)
    done
    zones_collected=true
}

setup_domain_data() {
    while (($# >= 3)); do
        local dom="$1" token="$3"
        domains[$dom]="$token ${domains[${dom}]:-}"
        shift 3
    done
}

get_zone_from_domain() {
    local domain="$1" zone
    collect_zones
    for zone in "${!zones[@]}"; do
        if [[ "${domain}." == *"$zone" || "${domain}." == "${zone}" ]]; then
            echo "$zone"
            return
        fi
    done
    return 1
}

build_rrset_records_payload() {
    local challenges="$1" challenge ret
    for challenge in $challenges; do
        ret="${ret},"'{"content":"\"'$challenge'\"","disabled":false,"set-ptr":false}'
    done
    echo "${ret:1}"
}

build_rrset_payload() {
    local name="$1" challenge="$2"
    echo -n "{\"name\":\"${name}\",\"type\":\"TXT\","
    if [[ -z "$challenge" ]]; then
        echo -n '"changetype":"DELETE"}'
        return
    fi
    echo -n '"ttl":1,"changetype":"REPLACE","records":['
    echo -n "$(build_rrset_records_payload "${challenge}")"
    echo ']}'
}

deploy_challenge_for() {
    local zone="$1" rrsets="$2"
    local server=${zones[$zone]}
    pdns_call PATCH servers/${server}/zones/"$zone" '{"rrsets":['${rrsets}']}'
    pdns_call PUT servers/${server}/zones/"$zone"/notify ''
    sleep 5
}

cmd() {
    local handler="$1"
    local domain zone
    local -A request
    shift
    collect_zones
    setup_domain_data "$@"
    for domain in "${!domains[@]}"; do
        local challenge
        zone=$(get_zone_from_domain "$domain")
        if [[ -n "$zone" ]]; then
            if [[ ${handler} == "deploy_challenge" ]]; then
                challenge="${domains[$domain]}"
            fi
            request[$zone]="${request[$zone]},$(build_rrset_payload "_acme-challenge.$domain." "$challenge")"
        fi
    done
    for zone in "${!request[@]}"; do
        deploy_challenge_for "$zone" "${request[$zone]:1}"
    done
}

main_func "$@"
