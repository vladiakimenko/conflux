
#!/usr/bin/env bash

assert_managed_container() {
    local container_name="$1"

    docker container inspect "$container_name" >/dev/null 2>&1 ||
        die "Container '$container_name' does not exist."

    local owner

    owner="$(
        docker inspect \
            --format '{{ index .Config.Labels "managed-by" }}' \
            "$container_name"
    )"

    [[ "$owner" == "$MANAGED_BY" ]] ||
        die "Container '$container_name' is not managed by Conflux."
}

create_forwarder() {
    local name="$1"
    local protocol="$2"
    local listen_ip="$3"
    local listen_port="$4"
    local target_ip="$5"
    local target_port="$6"

    local container_name
    container_name="$(container_name_for "$name")"

    local listen_spec
    local target_spec

    case "$protocol" in
        tcp)
            listen_spec="TCP-LISTEN:${listen_port},fork,reuseaddr"
            target_spec="TCP:${target_ip}:${target_port}"
            ;;
        udp)
            listen_spec="UDP-LISTEN:${listen_port},fork,reuseaddr"
            target_spec="UDP:${target_ip}:${target_port}"
            ;;
        *)
            die "Unsupported protocol: $protocol"
            ;;
    esac

    docker run -d \
        --name "$container_name" \
        --restart unless-stopped \
        --publish "${listen_ip}:${listen_port}:${listen_port}/${protocol}" \
        --label "managed-by=$MANAGED_BY" \
        --label "forwarder.name=$name" \
        --label "forwarder.protocol=$protocol" \
        --label "forwarder.listen-ip=$listen_ip" \
        --label "forwarder.listen-port=$listen_port" \
        --label "forwarder.target-ip=$target_ip" \
        --label "forwarder.target-port=$target_port" \
        "$CONFLUX_IMAGE" \
        "$listen_spec" \
        "$target_spec"
}

remove_forwarder() {
    local name="$1"

    local container_name
    container_name="$(container_name_for "$name")"

    assert_managed_container "$container_name"

    docker rm -f "$container_name" >/dev/null

    info "Removed container: $container_name"
}

restart_forwarder() {
    local name="$1"

    local container_name
    container_name="$(container_name_for "$name")"

    assert_managed_container "$container_name"

    docker restart "$container_name" >/dev/null
}

stop_forwarder() {
    local name="$1"

    local container_name
    container_name="$(container_name_for "$name")"

    assert_managed_container "$container_name"

    docker stop "$container_name" >/dev/null
}

list_forwarders() {
    local ids

    mapfile -t ids < <(
        docker ps -aq --filter "label=managed-by=$MANAGED_BY"
    )

    if ((${#ids[@]} == 0)); then
        printf 'No Conflux forwarders configured.\n'
        return
    fi

    printf '\n'
    printf '%-22s %-9s %-5s %-22s %-22s\n' \
        "NAME" "STATUS" "PROTO" "LISTEN" "DESTINATION"

    printf '%-22s %-9s %-5s %-22s %-22s\n' \
        "----------------------" \
        "---------" \
        "-----" \
        "----------------------" \
        "----------------------"

    local id
    local details

    for id in "${ids[@]}"; do
        if ! details="$(
            docker inspect --format \
                '{{ index .Config.Labels "forwarder.name" }}|{{ .State.Status }}|{{ index .Config.Labels "forwarder.protocol" }}|{{ index .Config.Labels "forwarder.listen-ip" }}|{{ index .Config.Labels "forwarder.listen-port" }}|{{ index .Config.Labels "forwarder.target-ip" }}|{{ index .Config.Labels "forwarder.target-port" }}' \
                "$id"
        )"; then
            warn "Could not inspect container $id"
            continue
        fi

        local name
        local state
        local protocol
        local listen_ip
        local listen_port
        local target_ip
        local target_port

        IFS='|' read -r \
            name state protocol listen_ip listen_port target_ip target_port \
            <<< "$details"

        [[ -n "$name" ]] || {
            warn "Skipping container $id: missing forwarder labels."
            continue
        }

        printf '%-22s %-9s %-5s %-22s %-22s\n' \
            "$name" \
            "$state" \
            "${protocol^^}" \
            "${listen_ip}:${listen_port}" \
            "${target_ip}:${target_port}"
    done

    printf '\n'
    printf 'Total: %s forwarder(s)\n\n' "${#ids[@]}"
}
